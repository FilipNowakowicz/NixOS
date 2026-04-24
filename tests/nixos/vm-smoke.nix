# Smoke test for the standard desktop VM.
{
  nixpkgs,
  system,
  inputs,
}:
let
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
in
(import "${nixpkgs}/nixos/lib/testing-python.nix" {
  inherit system pkgs;
}).runTest
  {
    name = "vm-smoke";
    node.specialArgs = { inherit inputs; };

    nodes.vm =
      { lib, config, ... }:
      {
        imports = [
          ../../hosts/vm/default.nix
          ../../modules/nixos/profiles/observability.nix
          ../../modules/nixos/services/systemd-failure-notify.nix
          inputs.home-manager.nixosModules.home-manager
          inputs.sops-nix.nixosModules.sops
        ];

        home-manager.extraSpecialArgs = {
          skipHeavyPackages = true;
        };

        sops = lib.mkForce {
          defaultSopsFile =
            let
              keys = lib.attrNames config.sops.secrets;
              yaml = lib.concatMapStrings (k: "${k}: test\n") keys;
            in
            builtins.toFile "dummy-secrets.yaml" yaml;
          secrets = {
            user_password.neededForUsers = false;
            observability_ingest_password.neededForUsers = false;
          };
        };
        users.users.user = {
          hashedPasswordFile = lib.mkForce null;
          hashedPassword = lib.mkForce "!";
        };
        services.systemd-failure-notify.enable = lib.mkForce false;
        profiles.observability.grafana.secretKeyFile = lib.mkForce (
          builtins.toFile "grafana-secret-key" "vm-smoke-secret"
        );

        environment.systemPackages = [ pkgs.curl ];
      };

    testScript = ''
      import os
      assert os.path.exists('/dev/kvm'), \
        "KVM not available: /dev/kvm missing. Smoke tests require KVM acceleration.\n" \
        "On Linux: enable nested KVM or run on hardware with KVM support.\n" \
        "On WSL: upgrade to WSL2 with --system-distro support or use nested hypervisor."

      start_all()

      vm.wait_for_unit("multi-user.target")
      vm.wait_for_unit("systemd-logind.service")
      vm.wait_for_unit("NetworkManager.service")
      vm.wait_for_unit("dbus.service")
    '';
  }
