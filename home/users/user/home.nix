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
      name = "power-profile";
      runtimeInputs = with pkgs; [ power-profiles-daemon ];
      text = ''
        current=$(powerprofilesctl get)
        case "$current" in
          power-saver) next=balanced ;;
          balanced)    next=performance ;;
          performance) next=power-saver ;;
          *)           next=balanced ;;
        esac
        powerprofilesctl set "$next"
      '';
    })

    (writeShellApplication {
      name = "battery-status";
      runtimeInputs = with pkgs; [ power-profiles-daemon ];
      text = ''
        get_bat_icon() {
          local pct=$1
          local icons=("󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹")
          local idx=$(( pct / 10 ))
          (( idx > 9 )) && idx=9
          echo "''${icons[$idx]}"
        }

        profile=$(powerprofilesctl get 2>/dev/null || echo "balanced")

        bat_dir=$(find /sys/class/power_supply -maxdepth 1 -name 'BAT*' 2>/dev/null | head -1)
        if [[ -z "$bat_dir" ]]; then
          printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "?" "$profile" "$profile"
          exit 0
        fi

        capacity=$(cat "$bat_dir/capacity")
        status=$(cat "$bat_dir/status")

        if [[ "$status" == "Full" ]]; then
          printf '{"text":"","tooltip":"%s","class":"full"}\n' "$profile"
          exit 0
        fi

        case "$status" in
          Charging) bat_icon="󰂄" ;;
          *)        bat_icon=$(get_bat_icon "$capacity") ;;
        esac

        classes="$profile"
        (( capacity <= 15 )) && classes="$classes critical"
        (( capacity > 15 && capacity <= 30 )) && classes="$classes warning"

        tooltip="$profile · ''${capacity}% · ''${status}"
        text="''${bat_icon}  ''${capacity}%"

        printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$text" "$tooltip" "$classes"
      '';
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
    ../../theme/module.nix
  ];

  themes.active = (import ../../theme/active.nix).name;

  gtk.gtk4.theme = null;

  programs = {
    # Home Manager owns ~/.ssh/config; VM aliases are injected via runtime
    # fragments under ~/.local/state/nixos-vms/ssh/.
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      includes = [
        "${config.home.homeDirectory}/.local/state/nixos-vms/ssh/*.conf"
      ];
    };

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
    # Config is managed by home/theme/module.nix (per-theme mako-config file,
    # symlinked at ~/.config/mako/config) so runtime theme-switch works without
    # a rebuild. Do not manage mako config here to avoid conflicts.
    mako.enable = true;

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
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.hypridle}/bin/hypridle -c %h/.config/hypr/hypridle.conf";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install = {
      WantedBy = [ "nixos-fake-graphical-session.target" ];
    };
  };
}
