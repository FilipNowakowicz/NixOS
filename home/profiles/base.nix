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
    neovim-unwrapped
    git
    lazygit
    nodejs
    python3
    python3Packages.flake8
    clang-tools
    gnumake
    gcc
    gnumake
    tree-sitter
  
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

  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      pull.ff = "only";
      core.editor = "nvim";
    };
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = false;
    };
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
