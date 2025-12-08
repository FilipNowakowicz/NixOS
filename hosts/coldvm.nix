{ inputs, ... }:
let
  username = "nixos";
in {
  imports = [
    ../modules/base.nix
    ../hardware/coldvm-hw.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  networking.hostName = "coldvm";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${username}.imports = [ ../home/default.nix ];
  };
}
