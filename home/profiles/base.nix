
{ config, pkgs, ... }:
{
  home.stateVersion = "24.11";
  programs.home-manager.enable = true;

  # CLI / dev / daily
  home.packages = with pkgs; [
    # core CLI
    bat
    btop
    eza
    fd
    fzf
    ripgrep
    jq
    tree
    unzip
    zip
    wget
    curl
    which
    less

    # shell / workflow
    zoxide
    tmux

    # editor / dev
    neovim
    git
    lazygit
    tree-sitter
    nodejs

    # utilities
    yazi
    hledger
    taskwarrior
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
