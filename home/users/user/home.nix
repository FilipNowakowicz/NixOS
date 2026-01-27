{ config, pkgs, ... }:
{
  home.username = "user";
  home.homeDirectory = "/home/user";

  home.stateVersion = "24.11";

  # make sure profiles are imported (if that’s your design)
  imports = [
    ../../profiles/base.nix
    ../../profiles/desktop.nix
  ];
}
