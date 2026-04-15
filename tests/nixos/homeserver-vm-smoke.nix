{ nixpkgs, system, inputs }:
let
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
in
(import "${nixpkgs}/nixos/lib/testing-python.nix" {
  inherit system pkgs;
}).runTest {
  name = "homeserver-vm-smoke";
  node.specialArgs = { inherit inputs; };

  nodes.machine = { lib, ... }: {
    imports = [
      ../../hosts/homeserver-vm/default.nix
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
    ];

    # Test-only overrides: avoid requiring decryptable sops user password.
    sops.defaultSopsFile = lib.mkForce (builtins.toFile "dummy-secrets.yaml" "user_password: test\n");
    sops.secrets.user_password = lib.mkForce { neededForUsers = false; };
    users.users.user.hashedPasswordFile = lib.mkForce null;
    users.users.user.hashedPassword = lib.mkForce "!";

    environment.systemPackages = [ pkgs.curl ];
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("vaultwarden.service")
    machine.wait_for_unit("nginx.service")
    machine.wait_for_unit("syncthing.service")
    machine.wait_for_unit("grafana.service")
    machine.wait_for_unit("loki.service")
    machine.wait_for_unit("tempo.service")
    machine.wait_for_unit("mimir.service")
    machine.wait_for_unit("prometheus.service")
    machine.wait_for_unit("prometheus-node-exporter.service")
    machine.wait_for_unit("alloy.service")
    machine.wait_for_unit("opentelemetry-collector.service")

    # Validate nginx TLS proxy to Vaultwarden.
    machine.succeed("curl -kfsS https://127.0.0.1:8443/ | grep -Eqi 'vaultwarden|bitwarden'")

    # Validate Syncthing GUI bind.
    machine.succeed("ss -ltn '( sport = :8384 )' | grep -q 127.0.0.1:8384")

    # Validate observability endpoints.
    machine.wait_until_succeeds("curl -fsS http://127.0.0.1:3000/api/health | grep -q '\"database\"[[:space:]]*:[[:space:]]*\"ok\"'")
    machine.wait_until_succeeds("curl -fsS http://127.0.0.1:3100/ready")
    machine.wait_until_succeeds("curl -fsS http://127.0.0.1:3200/ready")
    machine.wait_until_succeeds("curl -fsS http://127.0.0.1:9009/ready")
    machine.wait_until_succeeds("curl -fsS http://127.0.0.1:9090/-/ready")
  '';
}
