# NixOS & Home Manager Flake

A single, reproducible NixOS & Home Manager flake designed as a scalable, long-term setup.
The repository separates hardware, host identity, system profiles, and user configuration to support machines and VMs.

---

## Overview

- NixOS defines system state, services, hardware, and security.
- Home Manager is integrated as a NixOS module and used as the dotfiles system.
- Each host is built from reusable profiles plus a small host-specific definition.
- Theme colours live in `home/theme/colors.nix` and are consumed by generated configs (Hyprland, Waybar, Kitty, Rofi).

---

## Repository Structure

```
.
├── flake.nix                          # Entry point: hosts, home-manager, outputs
├── flake.lock
├── hosts
│   ├── main
│   │   ├── default.nix                # Primary machine config
│   │   └── hardware-configuration.nix
│   └── vm
│       ├── default.nix                # QEMU/KVM VM config (testing)
│       └── hardware-configuration.nix # Virtio drivers, systemd-boot
├── modules
│   └── nixos
│       └── profiles
│           ├── base.nix               # Nix settings, locale, zsh, essentials
│           ├── desktop.nix            # Hyprland, pipewire, portals, fonts
│           └── security.nix           # Firewall, sshd, sudo, sysctl hardening
└── home
    ├── profiles
    │   ├── base.nix                   # CLI tools, zsh, git, starship, fzf, zoxide
    │   └── desktop.nix                # GUI packages, GTK, mako, waybar, hyprpaper
    ├── theme
    │   ├── colors.nix                 # Gruvbox-warm palette (single source of truth)
    │   └── wallpapers
    │       └── wallpaper1.png
    ├── users
    │   └── user
    │       └── home.nix               # User entry point: git, zsh aliases, dotfile wiring
    └── files
        ├── hypr
        │   └── hyprland.conf          # Static Hyprland config (colors sourced at runtime)
        ├── kitty
        │   └── kitty.conf             # Terminal: font, opacity (theme generated from colors.nix)
        └── nvim                       # Neovim: Lazy.nvim, LSP, DAP, treesitter
            ├── init.lua
            └── lua/config/
```

---

## Hosts

| Host | Description | Deploy |
|------|-------------|--------|
| `main` | Primary workstation | `nixos-rebuild switch --flake .#main` |
| `vm`   | QEMU/KVM test VM    | `nixos-rebuild switch --flake .#vm --target-host nixvm --use-remote-sudo` |

To add a new host:
1. Create `hosts/<name>/hardware-configuration.nix`
2. Create `hosts/<name>/default.nix` importing the shared profiles
3. Add `<name> = mkNixos "<name>";` to `flake.nix`

---

## Stack

| Layer | Tool |
|-------|------|
| Window manager | Hyprland |
| Bar | Waybar |
| Terminal | Kitty |
| Editor | Neovim |
| Shell | Zsh |
| Prompt | Starship |
| Launcher | Rofi |
| Notifications | Mako |
| Screen lock | Hyprlock |
| Wallpaper | Hyprpaper |
| Clipboard | wl-clipboard |

---

## Validation

```bash
nix flake check
nix build '.#nixosConfigurations.vm.config.system.build.toplevel' --no-link
```
