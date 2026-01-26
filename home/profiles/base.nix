{ config, pkgs, ... }:
{
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    bat
    btop
    eza
    fd
    fzf
    git
    jq
    neovim
    ripgrep
    tmux
    unzip
    wget
    zip
    zoxide
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    PAGER = "less -R";
  };

  programs.git = {
    enable = true;
    userName = "Nix User";
    userEmail = "user@example.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.ff = "only";
      core.editor = "nvim";
    };
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    extraLuaConfig = ''
      vim.o.number = true
      vim.o.relativenumber = true
      vim.o.expandtab = true
      vim.o.shiftwidth = 2
      vim.o.tabstop = 2
      vim.o.termguicolors = true
      vim.cmd.colorscheme("default")
    '';
  };

  programs.tmux = {
    enable = true;
    clock24 = true;
    escapeTime = 10;
    historyLimit = 15000;
    extraConfig = ''
      set -g mouse on
      set -g status-bg colour237
      set -g status-fg colour250
      setw -g automatic-rename on
      setw -g aggressive-resize on
    '';
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      add_newline = false;
      character = {
        success_symbol = "[➜](bold green) ";
        error_symbol = "[➜](bold red) ";
      };
      git_branch.symbol = " ";
      git_status.disabled = false;
      directory = {
        truncate_to_repo = false;
        truncation_length = 3;
      };
    };
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    shellAliases = {
      ll = "eza -lh";
      la = "eza -lha";
      gs = "git status -sb";
      v = "nvim";
      cat = "bat --style=plain";
    };
    bashrcExtra = ''
      eval "$(zoxide init bash)"
      eval "$(starship init bash)"
    '';
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
  };

  xdg.configFile."shell/prompt.md".text = ''
    # Prompt design

    Prompt mirrored from the Arch install: minimal arrow showing status, concise path
    shortening, and git branch decoration.
  '';

  xdg.configFile."git/config.extras".text = ''
    [alias]
    co = checkout
    br = branch
    st = status -sb
    ci = commit
    df = diff
  '';

  xdg.configFile."nvim/lua/statusline.lua".text = ''
    local statusline = {}

    function statusline.active()
      return table.concat({
        '%#Identifier#  ',
        '%#Normal#%f',
        '%#Comment# %m',
        '%= ',
        '%#String#%l:%c ',
        '%#Number#[%p%%]'
      })
    end

    vim.o.statusline = "%!v:lua.statusline.active()"
    return statusline
  '';
}
