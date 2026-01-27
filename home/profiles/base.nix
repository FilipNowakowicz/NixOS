{ config, pkgs, ... }:
{
  home.stateVersion = "24.11";
  programs.home-manager.enable = true;

  # CLI packages
  home.packages = with pkgs; [
    # ── Core CLI ─────────────────────────────────────────────
    bat
    btop
    curl
    eza
    fd
    fzf
    jq
    less
    ripgrep
    tree
    unzip
    wget
    which
    zip
  
    # ── Shell / Workflow ─────────────────────────────────────
    tmux
    zoxide
  
    # ── Editor / Dev ─────────────────────────────────────────
    neovim
    git
    lazygit
    nodejs
    python3
    python3Packages.flake8
    clang-tools
    gnumake
  
    # ── Neovim helpers ───────────────────────────────────────
    glow        # :Glow markdown preview
  
    # ── Utilities ────────────────────────────────────────────
    yazi
    hledger
    taskwarrior3
    timewarrior
    yt-dlp
  ];
  home.sessionVariables = {
    EDITOR = "nvim";
    PAGER = "less -R";
  };

  # Git enabled, but NO identity here (set in home/users/user/home.nix)
  programs.git = {
    enable = true;
    extraConfig = {
      init.defaultBranch = "main";
      pull.ff = "only";
      core.editor = "nvim";
    };
  };

  # Neovim enabled (keep config tiny; move real config to home/files/ later)
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    extraLuaConfig = ''
      vim.o.number = true
      vim.o.relativenumber = true
      vim.o.termguicolors = true
    '';
  };

  programs.tmux = {
    enable = true;
    clock24 = true;
    escapeTime = 10;
    historyLimit = 15000;
    extraConfig = ''
      set -g mouse on
      setw -g automatic-rename on
      setw -g aggressive-resize on
    '';
  };

  # Prompt (optional, but fine)
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = false;
    };
  };

  # Zsh as the interactive shell config
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    shellAliases = {
      ll = "eza -lh";
      la = "eza -lha";
      gs = "git status -sb";
      v = "nvim";
      cat = "bat --style=plain";
    };

    initExtra = ''
      eval "$(zoxide init zsh)"
    '';
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}
