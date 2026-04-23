{ ... }:
{
  imports = [
    ./profiles/backup.nix
    ./profiles/observability.nix
    ./services/systemd-failure-notify.nix
    ./services/hardened.nix
  ];
}
