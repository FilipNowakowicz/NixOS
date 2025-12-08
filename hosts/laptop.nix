{ inputs, pkgs, ... }:
let
  username = "nixos";
  hmModules = [ ../home/default.nix ../home/desktop.nix ];
in {
  imports = [
    ../modules/base.nix
    ../modules/desktop.nix
    ../modules/security.nix
    ../hardware/laptop-hw.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  networking = {
    hostName = "laptop";
    networkmanager.enable = true;
    interfaces.wlan0.useDHCP = true;
    interfaces.enp2s0.useDHCP = true;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "America/New_York";

  environment.systemPackages = with pkgs; [ sway swaylock networkmanagerapplet thunderbird ];

  programs.swaylock.enable = true;
  services.logind.lidSwitch = "suspend";
  services.blueman.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${username}.imports = hmModules;
  };
}
