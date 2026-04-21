{ pkgs, ... }:
{
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
    basedpyright
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

  programs = {
    home-manager.enable = true;

    # ── Git ────────────────────────────────────────────────────────────────────
    git = {
      enable = true;
      settings = {
        init.defaultBranch = "main";
        pull.ff = "only";
        core.editor = "nvim";
      };
    };

    # ── Starship Prompt ────────────────────────────────────────────────────────
    starship = {
      enable = true;
      enableZshIntegration = false;
      settings = {
        add_newline = false;
        format = "$hostname$directory$python$nix_shell$character";
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
        python = {
          format = "[\\($symbol\\)]($style) ";
          symbol = "venv";
          style = "fg:#DAA520";
        };
        character = {
          success_symbol = "[%]()";
          error_symbol = "[%](red)";
        };
      };
    };

    # ── FZF ────────────────────────────────────────────────────────────────────
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    # ── Zoxide ─────────────────────────────────────────────────────────────────
    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    # ── Bat ────────────────────────────────────────────────────────────────────
    bat = {
      enable = true;
      config = {
        theme = "base16";
        italic-text = "always";
      };
    };
  };

  # ── SSH Agent ──────────────────────────────────────────────────────────────
  services.ssh-agent.enable = true;
}
