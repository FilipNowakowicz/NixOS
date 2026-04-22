{ ... }:
{
  imports = [
    ./profiles/base.nix
    ./profiles/desktop.nix
    ./profiles/security.nix
    ./profiles/observability.nix
    ./profiles/user.nix
    ./hardware/nvidia-prime.nix
    ./services/systemd-failure-notify.nix
  ];
}
