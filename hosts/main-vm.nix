{ inputs, ... }:
let
  username = "nixos";
  hmModules = [ ../home/default.nix ../home/desktop.nix ];
in {
  imports = [
    ../modules/base.nix
    ../hardware/main-vm-hw.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  networking.hostName = "main-vm";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${username}.imports = hmModules;
  };
}
