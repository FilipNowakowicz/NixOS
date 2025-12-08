{ inputs, ... }:
let
  username = "nixos";
in {
  imports = [
    ../modules/base.nix
    ../hardware/watchonly-hw.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  networking.hostName = "watchonly";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${username}.imports = [ ../home/default.nix ];
  };
}
