{ config, pkgs, ... }:
{
  programs.home-manager.enable = true;

  # ── Packages ────────────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    # Core CLI
    bat
    btop
    eza
    fd
    jq
    less
    ripgrep
    tree
    unzip
    which
    zip

    # Editor / Dev
    neovim-unwrapped
    lazygit
    nodejs
    python3
    clang-tools
    gnumake
    gcc
    tree-sitter
    nixd
    ruff
    stylua
    nixfmt

    # Neovim helpers
    glow # :Glow markdown preview

    # Utilities
    yazi
    yt-dlp
    nix-output-monitor
    nh

    # AI
    claude-code
    gemini-cli

    # GitHub / Steam
    gh
    steam-run
  ];

  # ── Environment Variables ──────────────────────────────────────────────────
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    MANPAGER = "nvim +Man!";
    PAGER = "less -R";
  };

  # ── Git ────────────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      pull.ff = "only";
      core.editor = "nvim";
    };
  };

  # ── Starship Prompt ────────────────────────────────────────────────────────
  programs.starship = {
    enable = true;
    enableZshIntegration = false;
    settings = {
      add_newline = false;
      format = "$hostname$directory$nix_shell$character";
      hostname = {
        ssh_only = true;
        format = "\\[[$hostname]($style)\\] ";
        style = "fg:#d79921 bold";
        trim_at = ".";
      };
      directory = {
        truncation_length = 2;
        truncate_to_repo = false;
        format = "$path ";
        style = "";
      };
      nix_shell = {
        format = "[\\($symbol\\)]($style) ";
        symbol = "nix";
        style = "fg:#83a598";
      };
      character = {
        success_symbol = "[%]()";
        error_symbol = "[%](red)";
      };
    };
  };

  # ── SSH Agent ──────────────────────────────────────────────────────────────
  services.ssh-agent.enable = true;

  # ── FZF ────────────────────────────────────────────────────────────────────
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # ── Zoxide ─────────────────────────────────────────────────────────────────
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # ── Zsh ────────────────────────────────────────────────────────────────────
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    history = {
      size = 10000;
      save = 10000;
      ignoreAllDups = true;
      share = true;
      append = true;
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

      # Use the shared systemd-managed SSH agent in every shell.
      export SSH_AUTH_SOCK="''${XDG_RUNTIME_DIR:-/run/user/$UID}/ssh-agent"
      # Load the default key once per login session when the agent is empty.
      if [[ -S "$SSH_AUTH_SOCK" ]]; then
        ssh-add -l >/dev/null 2>&1
        if [[ $? -eq 1 && -r "$HOME/.ssh/id_ed25519" ]]; then
          ssh-add -q "$HOME/.ssh/id_ed25519"
        fi
      fi

      # Accept autosuggestion with Ctrl+Space
      (( ''${+widgets[autosuggest-accept]} )) && bindkey '^ ' autosuggest-accept
      # Starship init
      eval "$(starship init zsh)"
    '';
  };

  # ── XDG User Dirs ──────────────────────────────────────────────────────────
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    download = "${config.home.homeDirectory}/downloads";
    desktop = null;
    documents = null;
    music = null;
    pictures = null;
    publicShare = null;
    templates = null;
    videos = null;
  };
}
