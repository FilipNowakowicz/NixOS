{ inputs, ... }:
let
  username = "nixos";
  hmModules = [ ../home/default.nix ../home/desktop.nix ];
in {
  imports = [
    ../modules/base.nix
    ../hardware/laptop-hw.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  networking.hostName = "laptop";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${username}.imports = hmModules;
  };
}
