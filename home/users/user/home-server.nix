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

  # ── Syncthing ──────────────────────────────────────────────────────────
  services.syncthing.enable = true;

  programs.git.signing.format = null;
  programs.zsh.shellAliases = {
    ll = "ls -lh --color=auto";
    la = "ls -A";
    l = "ls -CF";
  };
  xdg.userDirs.setSessionVariables = false;
}
