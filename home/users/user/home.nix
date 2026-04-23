{
  config,
  pkgs,
  ...
}:
let
  nixRepo = "${config.home.homeDirectory}/nix";
  privateUserJs = ../../files/firefox/private-user.js;
in
{
  home.packages = with pkgs; [
    (writeShellApplication {
      name = "theme-switch";
      runtimeInputs = with pkgs; [
        home-manager
        hyprland
        waybar
        swaybg
        kitty
        procps
        systemd
        libnotify
        fzf
      ];
      text = ''
        NIX_REPO="${nixRepo}"
      ''
      + builtins.readFile ../../files/scripts/theme-switch.sh;
    })

    (writeShellApplication {
      name = "waybar-weather";
      runtimeInputs = with pkgs; [ curl ];
      text = builtins.readFile ../../files/scripts/waybar-weather.sh;
    })

    (writeShellApplication {
      name = "clipboard-pick";
      runtimeInputs = with pkgs; [
        cliphist
        fzf
        wl-clipboard
      ];
      text = builtins.readFile ../../files/scripts/clipboard-pick.sh;
    })

    (writeShellApplication {
      name = "firefox-private";
      runtimeInputs = [ pkgs.firefox ];
      text = ''
        profile=$(mktemp -d)
        trap 'rm -rf "$profile"' EXIT
        cp ${privateUserJs} "$profile/user.js"
        exec firefox --profile "$profile" --no-remote "$@"
      '';
    })

    hypridle
    opencode
    opencode-claude-auth
  ];

  imports = [
    ./common.nix
    ../../profiles/desktop.nix
    ../../profiles/workstation.nix
    ../../theme/module.nix
  ];

  themes.active = (import ../../theme/active.nix).name;

  gtk.gtk4.theme = null;

  programs = {
    # ── Direnv ─────────────────────────────────────────────────────────────
    direnv = {
      enable = true;
      enableZshIntegration = true;
    };

    # ── Zsh ────────────────────────────────────────────────────────────────
    # Base options, plugins, and vi-mode are set in home/profiles/base.nix
    # Shared aliases and shell functions are in common.nix
    zsh = {
      shellAliases = {
        rebuild = "nh os switch --hostname main .";
        theme = "theme-switch";
        cb = "clipboard-pick";
        copilot = "steam-run gh copilot";
      };

      initContent = ''
        _theme_switch_completion() {
          local themes
          themes=($(ls ${nixRepo}/home/theme/themes | sed 's/\.nix//'))
          _describe 'themes' themes
        }
        compdef _theme_switch_completion theme-switch
      '';
    };
  };

  # ── XDG MIME Apps ──────────────────────────────────────────────────────
  xdg = {
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
      };
    };

    # ── Themes & Config Files ──────────────────────────────────────────────
    configFile = {
      # Kitty
      "kitty/kitty.conf".source = ../../files/kitty/kitty.conf;

      # Hyprland
      "hypr/hyprland.conf".source = ../../files/hypr/hyprland.conf;

      # Hyprlock
      "hypr/hyprlock.conf".source = ../../files/hypr/hyprlock.conf;

      # Waybar
      "waybar/config".source = ../../files/waybar/config;
      "waybar/style.css".source = ../../files/waybar/style.css;

      "hypr/hypridle.conf" = {
        force = true;
        text = ''
          general {
            after-sleep-cmd = hyprctl dispatch dpms on
            before-sleep-cmd = loginctl lock-session
            lock-cmd = pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock
          }

          listener {
            on-timeout = pidof hyprlock > /dev/null || ${pkgs.hyprlock}/bin/hyprlock
            timeout = 300
          }

          listener {
            on-timeout = hyprctl dispatch dpms off
            on-resume = hyprctl dispatch dpms on
            timeout = 330
          }

          listener {
            on-timeout = ${pkgs.systemd}/bin/systemctl suspend
            timeout = 900
          }
        '';
      };
    };
  };

  services = {
    # ── Syncthing ──────────────────────────────────────────────────────────
    syncthing.enable = false;

    # ── Cliphist ────────────────────────────────────────────────────────────
    cliphist.enable = true;

    # ── Mako ───────────────────────────────────────────────────────────────
    mako = {
      enable = true;
      settings = {
        font = "JetBrainsMono Nerd Font 11";
        background-color = "#${config.themes._activeThemeColors.bg}";
        text-color = "#${config.themes._activeThemeColors.text}";
        border-color = "#${config.themes._activeThemeColors.orange}";
        border-radius = 8;
        border-size = 2;
        anchor = "top-right";
        margin = "12";
        padding = "10,14";
        width = 300;
        default-timeout = 5000;
        max-visible = 5;
      };
    };

    # ── Hypridle ───────────────────────────────────────────────────────────
    # Hyprland-native idle daemon. Single source of truth for desktop idle
    # behavior: lock at 10 minutes, suspend at 15 minutes.
    #
    # Uses loginctl lock-session so Hyprland's session-lock protocol handles
    # hyprlock lifecycle independently of the idle timer.
    #
    # NOTE: home-manager's hypridle module generates on_timeout (underscore)
    # but hypridle 0.1.7 requires on-timeout (dash). Module is disabled and
    # replaced with a handwritten config file plus user service unit.
    hypridle.enable = false;
  };

  # Start with the same user target that Hyprland explicitly starts in
  # ~/.config/hypr/hyprland.conf (nixos-fake-graphical-session.target).
  systemd.user.services.hypridle = {
    Unit = {
      Description = "hypridle";
      After = [ "nixos-fake-graphical-session.target" ];
      PartOf = [ "nixos-fake-graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = "${pkgs.hypridle}/bin/hypridle -c %h/.config/hypr/hypridle.conf";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install = {
      WantedBy = [ "nixos-fake-graphical-session.target" ];
    };
  };
}
