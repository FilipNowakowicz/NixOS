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
    settings.user.name = "Filip Nowakowicz";
    settings.user.email = "filip.nowakowicz@gmail.com";
  };

  # Zsh configuration
  home.file.".zshenv".source = ../../files/zsh/zshenv;
  home.file.".zshrc".source  = ../../files/zsh/zshrc;

  # XDG configuration
  xdg.enable = true;
  xdg.configFile."nvim".source = ../../files/nvim;
  xdg.configFile."kitty".source  = ../../files/kitty;
  xdg.configFile."tmux".source   = ../../files/tmux;
  xdg.configFile."awesome".source = ../../files/awesome;
}
