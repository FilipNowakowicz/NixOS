{ inputs, ... }:
let
  username = "nixos";
in {
  imports = [
    ../modules/base.nix
    ../hardware/labvm-hw.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  networking.hostName = "labvm";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${username}.imports = [ ../home/default.nix ];
  };
}
