{ config, pkgs, ... }:
{
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # ── Core CLI ─────────────────────────────────────────────
    bat
    btop
    curl
    eza
    fd
    jq
    less
    ripgrep
    tree
    unzip
    wget
    which
    zip

    # ── Editor / Dev ─────────────────────────────────────────
    neovim-unwrapped
    lazygit
    nodejs
    python3
    python3Packages.flake8
    clang-tools
    gnumake
    gcc
    tree-sitter

    # ── Neovim helpers ───────────────────────────────────────
    glow        # :Glow markdown preview

    # ── Utilities ────────────────────────────────────────────
    yazi
    taskwarrior3
    timewarrior
    yt-dlp
  ];

  home.sessionVariables = {
    EDITOR   = "nvim";
    VISUAL   = "nvim";
    MANPAGER = "nvim +Man!";
    PAGER    = "less -R";
  };

  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      pull.ff            = "only";
      core.editor        = "nvim";
    };
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = false;
      format = "$directory$character";
      directory = {
        truncation_length = 2;
        truncate_to_repo  = false;
        format            = "$path ";
        style             = "";
      };
      character = {
        success_symbol = "[%]()";
        error_symbol   = "[%](red)";
      };
    };
  };

  programs.keychain = {
    enable = true;
    enableZshIntegration = true;
    keys       = [ "id_ed25519" ];
    extraFlags = [ "--quiet" ];
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable   = true;
    dotDir   = "${config.xdg.configHome}/zsh";
    autosuggestion.enable     = true;
    syntaxHighlighting.enable = true;
    enableCompletion          = true;

    history = {
      size          = 10000;
      save          = 10000;
      ignoreAllDups = true;
      share         = true;
      append        = true;
    };

    initContent = ''
      # Options
      setopt autocd correct extendedglob noclobber
      setopt interactivecomments nobeep
      setopt autopushd pushdignoredups
      setopt nohup nocheckjobs

      # Vi mode + edit in $EDITOR
      bindkey -v
      autoload -Uz edit-command-line; zle -N edit-command-line
      bindkey -M vicmd 'v' edit-command-line

      # History-prefix search on arrows
      autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
      zle -N up-line-or-beginning-search
      zle -N down-line-or-beginning-search
      bindkey '^[[A' up-line-or-beginning-search
      bindkey '^[[B' down-line-or-beginning-search

      # Completion styling
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
      zstyle ':completion:*' menu select
      zstyle ':completion:*' use-cache on
      zstyle ':completion:*' cache-path "''${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
      zstyle ':completion:*' rehash true

      # Accept autosuggestion with Ctrl+Space
      (( ''${+widgets[autosuggest-accept]} )) && bindkey '^ ' autosuggest-accept
    '';
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    download    = "${config.home.homeDirectory}/downloads";
    desktop     = null;
    documents   = null;
    music       = null;
    pictures    = null;
    publicShare = null;
    templates   = null;
    videos      = null;
  };
}
