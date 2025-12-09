{ config, pkgs, ... }:
{
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };

    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
    };
  };

  time.timeZone = "UTC";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  users = {
    defaultUserShell = pkgs.zsh;

    users = {
      root.shell = pkgs.zsh;

      user = {
        isNormalUser = true;
        description = "Primary user";
        extraGroups = [ "wheel" "networkmanager" "audio" "video" ];
        shell = pkgs.zsh;
      };
    };
  };

  programs = {
    zsh.enable = true;
    fish.enable = true;
  };

  services.openssh.enable = true;

  environment = {
    shells = [ pkgs.zsh pkgs.fish pkgs.bashInteractive ];

    systemPackages = with pkgs; [
      curl
      git
      gnupg
      htop
      neovim
      openssh
      ripgrep
      rsync
      tree
      unzip
      wget
      which
      zip
    ];
  };
}
