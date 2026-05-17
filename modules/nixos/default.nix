{ ... }:
{
  imports = [
    ./profiles/backup.nix
    ./profiles/meta.nix
    ./profiles/observability
    ./services/systemd-failure-notify.nix
    ./services/hardened.nix
  ];
}
