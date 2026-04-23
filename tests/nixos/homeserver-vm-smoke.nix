# Smoke test for the homeserver services in a VM environment.
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
    name = "homeserver-vm-smoke";
    node.specialArgs = { inherit inputs; };

    nodes.homeserver =
      { lib, config, ... }:
      {
        imports = [
          ../../hosts/homeserver-vm/default.nix
          ../../modules/nixos/services/hardened.nix
          inputs.home-manager.nixosModules.home-manager
          inputs.sops-nix.nixosModules.sops
        ];

        # Test-only overrides: avoid requiring decryptable sops user password.
        sops.defaultSopsFile = lib.mkForce (
          let
            keys = lib.attrNames config.sops.secrets;
            yaml = lib.concatMapStrings (k: "${k}: test\n") keys;
          in
          builtins.toFile "dummy-secrets.yaml" yaml
        );
        sops.secrets.user_password = lib.mkForce { neededForUsers = false; };
        users.users.user.hashedPasswordFile = lib.mkForce null;
        users.users.user.hashedPassword = lib.mkForce "!";
        profiles.observability.grafana.secretKeyFile = lib.mkForce (
          builtins.toFile "grafana-secret-key" "vm-smoke-grafana-secret-key"
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

      homeserver.wait_for_unit("multi-user.target")
      homeserver.wait_for_unit("vaultwarden.service")
      homeserver.wait_for_unit("nginx.service")
      homeserver.wait_for_unit("syncthing.service")
      homeserver.wait_for_unit("grafana.service")
      homeserver.wait_for_unit("loki.service")
      homeserver.wait_for_unit("tempo.service")
      homeserver.wait_for_unit("mimir.service")
      homeserver.wait_for_unit("prometheus.service")
      homeserver.wait_for_unit("prometheus-node-exporter.service")
      homeserver.wait_for_unit("alloy.service")
      homeserver.wait_for_unit("opentelemetry-collector.service")

      # Validate nginx TLS proxy to Vaultwarden.
      homeserver.succeed("curl -kfsS https://127.0.0.1:8443/ | grep -Eqi 'vaultwarden|bitwarden'")

      # Validate Syncthing GUI bind.
      homeserver.succeed("ss -ltn '( sport = :8384 )' | grep -q 127.0.0.1:8384")

      # Validate observability endpoints.
      homeserver.wait_until_succeeds("curl -fsS http://127.0.0.1:3000/api/health | grep -q '\"database\"[[:space:]]*:[[:space:]]*\"ok\"'")
      homeserver.wait_until_succeeds("curl -fsS http://127.0.0.1:3100/ready")
      homeserver.wait_until_succeeds("curl -fsS http://127.0.0.1:3200/ready")
      homeserver.wait_until_succeeds("curl -fsS http://127.0.0.1:9009/ready")
      homeserver.wait_until_succeeds("curl -fsS http://127.0.0.1:9090/-/ready")
    '';
  }
