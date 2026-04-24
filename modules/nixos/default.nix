{ ... }:
{
  imports = [
    ./profiles/backup.nix
    ./profiles/observability
    ./services/systemd-failure-notify.nix
    ./services/hardened.nix
  ];
}
