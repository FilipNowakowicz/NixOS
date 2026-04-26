{ lib, ... }:
{
  security.sudo.wheelNeedsPassword = false;

  services.openssh.openFirewall = true;

  nix.settings.trusted-users = lib.mkForce [
    "root"
    "user"
  ];
}
