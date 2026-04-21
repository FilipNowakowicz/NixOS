{ config, ... }:
{
  home = {
    username = "user";
    homeDirectory = "/home/user";
    stateVersion = "24.11";

    # ── PATH ───────────────────────────────────────────────────────────────
    sessionPath = [
      "${config.home.homeDirectory}/.local/bin"
      "${config.home.homeDirectory}/.npm-global/bin"
    ];
  };

  imports = [
    ../../profiles/base.nix
  ];

  # ── Git ────────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    settings.user.name = "Filip Nowakowicz";
    settings.user.email = "filip.nowakowicz@gmail.com";
    signing.format = null;
  };

  # ── Zsh ────────────────────────────────────────────────────────────────
  programs.zsh = {
    shellAliases = {
      # Files
      ll = "ls -lh --color=auto";
      la = "ls -A";
      l = "ls -CF";
      cp = "cp -i";
      mv = "mv -i";
      # Navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      d = "dirs -v";
      # Git
      g = "git";
      ga = "git add";
      gd = "git diff";
      gco = "git checkout";
      gb = "git branch";
      gc = "git commit -m";
      gca = "git commit -am";
      gp = "git push";
      gl = "git pull";
      glog = "git log --oneline --graph --decorate";
      gs = "git status";
    };

    initContent = ''
      mkcd()   { mkdir -p -- "$1" && cd -- "$1"; }
      detach() { setsid -f "$@" >/dev/null 2>&1 < /dev/null; }
      extract() {
        [[ -f "$1" ]] || { echo "extract: file not found: $1" >&2; return 1; }
        case "$1" in
          *.tar.bz2) tar xjf "$1" ;;
          *.tar.gz)  tar xzf "$1" ;;
          *.tar.xz)  tar xJf "$1" ;;
          *.tar.zst) tar --zstd -xf "$1" ;;
          *.zip)     unzip "$1" ;;
          *.7z)      7z x "$1" ;;
          *) echo "extract: unsupported format: $1" >&2; return 2 ;;
        esac
      }

      bindkey "''${terminfo[kcuu1]}" history-beginning-search-backward
      bindkey "''${terminfo[kcud1]}" history-beginning-search-forward
    '';
  };

  # ── Neovim config ──────────────────────────────────────────────────────
  xdg.configFile."nvim".source = ../../files/nvim;
}
