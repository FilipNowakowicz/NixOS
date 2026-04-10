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

  programs.git.signing.format = null;
  xdg.userDirs.setSessionVariables = false;
}
