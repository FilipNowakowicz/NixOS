{ config, pkgs, ... }:
{
  home.username = "user";
  home.homeDirectory = "/home/user";
  home.stateVersion = "24.11";

  imports = [
    ../../profiles/base.nix
    ../../profiles/desktop.nix
  ];

  home.file.".zshenv".source = ../../files/zsh/zshenv;
  home.file.".zshrc".source  = ../../files/zsh/zshrc;
}
