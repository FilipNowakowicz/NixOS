{ config, pkgs, ... }:
{
  home.username = "user";
  home.homeDirectory = "/home/user";
  home.stateVersion = "24.11";

  imports = [
    ../../profiles/base.nix
    ../../profiles/desktop.nix
  ];

  programs.git = {
    enable = true;
    userName = "Filip Nowakowicz";
    userEmail = "filip.nowakowicz@gmail.com";
  };

  # Zsh configuration
  home.file.".zshenv".source = ../../files/zsh/zshenv;
  home.file.".zshrc".source  = ../../files/zsh/zshrc;

  # Neovim configuration
  xdg.enable = true;
  xdg.configFile."nvim".source = ../../files/nvim;
}
