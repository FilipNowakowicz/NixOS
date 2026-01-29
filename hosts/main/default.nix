{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/desktop.nix
    ../../modules/nixos/profiles/security.nix
  ];

  system.stateVersion = "24.11";

  networking = {
    hostName = "main";
    networkmanager.enable = true;
  };

  services.logind.settings = {
    Login.HandleLidSwitch = "suspend";
    # Optional: keep running on AC power
    # lidSwitchExternalPower = "ignore";
  };

  users.users.user = {
    isNormalUser = true;
    description = "Primary user";
    extraGroups = [ "wheel" "networkmanager" "video" ];
    shell = pkgs.zsh;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.user = {
      imports = [ ../../home/users/user/home.nix ];
    };
  };
}
