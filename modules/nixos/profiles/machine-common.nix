{ lib, ... }:
{
  services.openssh = {
    enable = true;
    openFirewall = lib.mkDefault false;
  };
}
