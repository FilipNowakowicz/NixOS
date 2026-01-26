{ config, pkgs, ... }:
{
  imports = [
    ../../profiles/base.nix
    ../../profiles/desktop.nix
  ];
}
