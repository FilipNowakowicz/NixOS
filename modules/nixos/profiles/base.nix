{ pkgs, ... }:
{
  zramSwap.enable = true;

  # ── Nix ────────────────────────────────────────────────────────────────────
  nixpkgs.config.allowUnfree = true;
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      extra-substituters = [ "https://filipnowakowicz.cachix.org" ];
      extra-trusted-public-keys = [
        "filipnowakowicz.cachix.org-1:QLgU0QAdYs9DoRBgVLuJjPT5etR10sqv75+s/B68jCA="
      ];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # ── Localization ───────────────────────────────────────────────────────────
  time.timeZone = "Europe/Warsaw";
  i18n.defaultLocale = "en_GB.UTF-8";
  console.keyMap = "dvorak";

  # ── Shell ───────────────────────────────────────────────────────────────────
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # ── System Packages ────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    curl
    pciutils
    rsync
    usbutils
    wget
  ];
}
