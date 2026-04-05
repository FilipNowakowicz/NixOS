{ config, pkgs, ... }:
let
  colors = import ../../theme/colors.nix;
in
{
  home.username = "user";
  home.homeDirectory = "/home/user";
  home.stateVersion = "24.11";

  imports = [
    ../../profiles/base.nix
    ../../profiles/desktop.nix
  ];

  programs.git = {
    enable = true;
    settings.user.name = "Filip Nowakowicz";
    settings.user.email = "filip.nowakowicz@gmail.com";
  };

  # PATH addition from ~/.local/bin
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  # Zsh — user-specific aliases and shell functions
  # Base options, plugins, and vi-mode are set in home/profiles/base.nix
  programs.zsh = {
    shellAliases = {
      # ── Files ──────────────────────────────────────────────
      ll   = "ls -lh --color=auto";
      la   = "ls -A";
      l    = "ls -CF";
      cp   = "cp -i";
      mv   = "mv -i";
      # ── Navigation ─────────────────────────────────────────
      ".."   = "cd ..";
      "..."  = "cd ../..";
      "...." = "cd ../../..";
      d      = "dirs -v";
      # ── Git ────────────────────────────────────────────────
      g    = "git";
      ga   = "git add";
      gd   = "git diff";
      gco  = "git checkout";
      gb   = "git branch";
      gc   = "git commit -m";
      gca  = "git commit -am";
      gp   = "git push";
      gl   = "git pull";
      glog = "git log --oneline --graph --decorate";
      # ── System ─────────────────────────────────────────────
      battery          = "acpi -b";
      buds             = "bluetoothctl connect DC:69:E2:CF:9A:BD";
      headset          = "bluetoothctl connect 40:58:99:3D:C8:D3";
      whatsapp         = "wasistlos &";
      vnc-on           = ''systemctl --user start x0vncserver.service && echo "VNC started"'';
      vnc-off          = ''systemctl --user stop x0vncserver.service && echo "VNC stopped"'';
      vnc-status       = "systemctl --user status x0vncserver.service --no-pager";
      tailscale-on     = ''sudo systemctl start tailscaled && sudo tailscale up && echo "Tailscale connected"'';
      tailscale-off    = ''sudo systemctl stop tailscaled && echo "Tailscale stopped"'';
      tailscale-status = "tailscale status";
      ollama3          = "ollama run llama3.1:8b";
      ollamamath       = "ollama run wizard-math:7b";
      backup           = "sudo -E /usr/local/bin/backup-borg.sh";
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
    '';
  };

  # Wallpaper
  home.file.".local/share/wallpapers/wallpaper1.png".source =
    ../../theme/wallpapers/wallpaper1.png;

  xdg.enable = true;

  # ── Neovim / Tmux ────────────────────────────────────────────────────────────
  xdg.configFile."nvim".source = ../../files/nvim;

  # ── Kitty ────────────────────────────────────────────────────────────────────
  # Per-file so current-theme.conf can be generated from colors.nix
  xdg.configFile."kitty/kitty.conf".source = ../../files/kitty/kitty.conf;
  xdg.configFile."kitty/current-theme.conf".text = ''
    # vim:ft=kitty
    ## name: Gruvbox Warm

    foreground           #${colors.text}
    background           #${colors.bg}
    selection_foreground #${colors.text}
    selection_background #${colors.brown}

    cursor            #${colors.amber}
    cursor_text_color #${colors.bg}

    url_color #${colors.amber}

    active_border_color   #${colors.amber}
    inactive_border_color #${colors.brown}
    bell_border_color     #${colors.orange}

    wayland_titlebar_color #${colors.bg}

    active_tab_foreground   #${colors.text}
    active_tab_background   #${colors.bg}
    inactive_tab_foreground #${colors.brown}
    inactive_tab_background #${colors.bg}
    tab_bar_background      #${colors.bg}

    # 16 colors — gruvbox-warm extended palette
    color0  #${colors.bg}
    color8  #${colors.brown}
    color1  #cc241d
    color9  #fb4934
    color2  #98971a
    color10 #b8bb26
    color3  #${colors.amber}
    color11 #fabd2f
    color4  #458588
    color12 #83a598
    color5  #b16286
    color13 #d3869b
    color6  #689d6a
    color14 #8ec07c
    color7  #${colors.text}
    color15 #fbf1c7
  '';

  # ── Hyprland ─────────────────────────────────────────────────────────────────
  xdg.configFile."hypr/hyprland.conf".source = ../../files/hypr/hyprland.conf;
  xdg.configFile."hypr/colors.conf".text = ''
    $col_active   = rgb(${colors.amber})
    $col_inactive = rgb(${colors.brown})
  '';
  xdg.configFile."hypr/hyprpaper.conf".text = ''
    preload   = ~/.local/share/wallpapers/wallpaper1.png
    wallpaper = ,~/.local/share/wallpapers/wallpaper1.png
    splash    = false
  '';

  # ── Waybar ───────────────────────────────────────────────────────────────────
  xdg.configFile."waybar/config".text = ''
    {
        "layer": "top",
        "position": "top",
        "margin-top": 8,
        "margin-left": 12,
        "margin-right": 12,
        "spacing": 0,

        "modules-left":   ["hyprland/workspaces"],
        "modules-center": ["clock"],
        "modules-right":  ["group/right"],

        "hyprland/workspaces": {
            "format": "{icon}",
            "format-icons": {
                "active":  "●",
                "default": "○"
            },
            "on-click": "activate",
            "sort-by-number": true
        },

        "clock": {
            "format": "{:%H:%M\n%a %d %b}",
            "tooltip-format": "<tt><small>{calendar}</small></tt>",
            "calendar": {
                "mode": "month",
                "on-scroll": 1,
                "format": {
                    "today": "<span color='#${colors.amber}'><b>{}</b></span>"
                }
            },
            "on-click": "gsimplecal"
        },

        "group/right": {
            "orientation": "horizontal",
            "modules": ["network", "pulseaudio", "tray"]
        },

        "network": {
            "format-wifi":        "  {essid}",
            "format-ethernet":    "󰈀  {ifname}",
            "format-disconnected": "󰤭",
            "tooltip-format": "{ifname}: {ipaddr}/{cidr}",
            "max-length": 20
        },

        "pulseaudio": {
            "format":       "{icon}  {volume}%",
            "format-muted": "󰝟  muted",
            "format-icons": {
                "default": ["󰕿", "󰖀", "󰕾"]
            },
            "on-click":    "pavucontrol",
            "scroll-step": 5
        },

        "tray": {
            "icon-size": 16,
            "spacing":    8
        }
    }
  '';

  xdg.configFile."waybar/style.css".text = ''
    * {
        font-family: "Inter", "JetBrainsMono Nerd Font", sans-serif;
        font-size: 13px;
        min-height: 0;
    }

    window#waybar {
        background: transparent;
        color: #${colors.text};
    }

    /* ── Pills ────────────────────────────────────────────── */

    #workspaces,
    #clock,
    #right {
        background: rgba(28, 26, 24, 0.70);
        border-radius: 12px;
        margin: 8px 4px;
        padding: 0 8px;
        border: 1px solid rgba(196, 110, 26, 0.30);
    }

    /* ── Workspaces ───────────────────────────────────────── */

    #workspaces button {
        padding:    0 6px;
        color:      #${colors.brown};
        background: transparent;
        font-size:  10px;
        transition: color 150ms ease;
        box-shadow: none;
    }

    #workspaces button.active {
        color: #${colors.amber};
    }

    #workspaces button:hover {
        color:      #${colors.text};
        background: transparent;
        box-shadow: none;
    }

    /* ── Clock ────────────────────────────────────────────── */

    #clock {
        padding:     0 20px;
        font-weight: 500;
        font-size:   14px;
    }

    /* ── Right group ──────────────────────────────────────── */

    #network,
    #pulseaudio,
    #tray {
        padding:    0 10px;
        background: transparent;
        color:      #${colors.text};
    }

    /* ── Status ───────────────────────────────────────────── */

    #battery.warning  { color: #${colors.orange}; }
    #battery.critical { color: #${colors.amber};  }
  '';

  # ── Mako ─────────────────────────────────────────────────────────────────────
  services.mako = {
    enable = true;
    settings = {
      font             = "JetBrainsMono Nerd Font 11";
      background-color = "#${colors.bg}";
      text-color       = "#${colors.text}";
      border-color     = "#${colors.orange}";
      border-radius    = 8;
      border-size      = 2;
      anchor           = "top-right";
      margin           = "12";
      padding          = "10 14";
      width            = 300;
      default-timeout  = 5000;
      max-visible      = 5;
    };
  };

  # ── Hyprlock ─────────────────────────────────────────────────────────────────
  xdg.configFile."hypr/hyprlock.conf".text = ''
    general {
      disable_loading_bar = true
      hide_cursor         = true
      grace               = 0
    }

    background {
      monitor =
      path        = ~/.local/share/wallpapers/wallpaper1.png
      blur_passes = 3
      blur_size   = 8
      brightness  = 0.5
    }

    # Clock
    label {
      monitor     =
      text        = $TIME
      color       = rgba(${colors.text}ff)
      font_size   = 72
      font_family = JetBrainsMono Nerd Font
      halign      = center
      valign      = center
      position    = 0, 160
    }

    # Password input
    input-field {
      monitor          =
      size             = 240, 48
      outline_thickness = 2
      dots_size        = 0.2
      dots_spacing     = 0.35
      outer_color      = rgb(${colors.amber})
      inner_color      = rgb(${colors.bg})
      font_color       = rgb(${colors.text})
      fade_on_empty    = true
      placeholder_text = <i>Password</i>
      check_color      = rgb(${colors.amber})
      fail_color       = rgb(cc241d)
      fail_text        = <i>$FAIL ($ATTEMPTS)</i>
      halign           = center
      valign           = center
      position         = 0, -80
    }
  '';

  # ── Rofi ─────────────────────────────────────────────────────────────────────
  xdg.configFile."rofi/config.rasi".text = ''
    configuration {
        modi:                "drun,run";
        show-icons:          true;
        display-drun:        "";
        drun-display-format: "{name}";
    }

    * {
        bg:     #${colors.bg};
        bg-alt: #${colors.brown};
        fg:     #${colors.text};
        accent: #${colors.amber};

        background-color: transparent;
        text-color:       @fg;
    }

    window {
        background-color: @bg;
        border:           2px solid;
        border-color:     @accent;
        border-radius:    12px;
        width:            30%;
    }

    inputbar {
        background-color: @bg-alt;
        border-radius:    8px;
        margin:           8px;
        padding:          8px 12px;
        children:         [prompt, entry];
    }

    prompt {
        text-color: @accent;
        margin:     0 8px 0 0;
    }

    entry {
        placeholder:       "Search…";
        placeholder-color: @bg-alt;
    }

    listview {
        padding: 4px 8px 8px;
        spacing: 2px;
    }

    element {
        padding:       8px 12px;
        border-radius: 8px;
    }

    element selected {
        background-color: @bg-alt;
        text-color:       @accent;
    }

    element-icon {
        size:   20px;
        margin: 0 8px 0 0;
    }
  '';
}
