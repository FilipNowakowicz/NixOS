{ ... }:
{
  home = {
    username = "user";
    homeDirectory = "/home/user";
    stateVersion = "24.11";
  };

  imports = [
    ../../profiles/base.nix
  ];
}
