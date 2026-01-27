{ pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # OS Essential Packages
  environment.systemPackages = with pkgs; [
    curl
    gnupg
    pciutils
    rsync
    usbutils
    wget
  ];
}
