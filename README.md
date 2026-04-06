# NixOS & Home Manager Flake

A single, reproducible NixOS & Home Manager flake designed as a scalable, long-term setup.
The repository separates hardware, host identity, system profiles, and user configuration to support multiple machines and VMs.

---

## Overview

- NixOS defines system state, services, hardware, and security.
- Home Manager is integrated as a NixOS module and used as the dotfiles system.
- Each host is built from reusable profiles plus a small host-specific definition.
- Theme colours live in `home/theme/colors.nix` and are consumed by generated configs (Hyprland, Waybar, Kitty, Rofi).
- Disk layouts are declared with disko and applied via nixos-anywhere on fresh installs.

---

## Repository Structure

```
.
├── flake.nix                          # Entry point: hosts, home-manager, deploy-rs, disko
├── flake.lock
├── hosts
│   ├── main
│   │   ├── default.nix                # Primary machine config
│   │   ├── disko.nix                  # Declarative disk layout (/dev/nvme0n1)
│   │   └── hardware-configuration.nix
│   └── vm
│       ├── default.nix                # QEMU/KVM VM config (testing)
│       ├── disko.nix                  # Declarative disk layout (/dev/vda)
│       └── hardware-configuration.nix
├── modules
│   └── nixos
│       └── profiles
│           ├── base.nix               # Nix settings, locale, zsh, essentials
│           ├── desktop.nix            # Hyprland, pipewire, portals, fonts
│           └── security.nix           # Firewall, sshd, sysctl hardening
└── home
    ├── profiles
    │   ├── base.nix                   # CLI tools, zsh, git, starship, fzf, zoxide
    │   └── desktop.nix                # GUI packages, GTK, cursor, mako, waybar
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
| `vm`   | QEMU/KVM test VM    | `deploy .#vm` (from dev shell) |

### Fresh VM install

```bash
# 1. Create disk image
qemu-img create -f qcow2 /vmstore/images/nixos-test.qcow2 40G

# 2. Boot NixOS ISO in the VM, then from the Arch host:
nix develop
nixos-anywhere --flake '.#vm' root@nixvm

# 3. After reboot, deploy updates normally:
deploy .#vm
```

To add a new host:
1. Create `hosts/<name>/hardware-configuration.nix`
2. Create `hosts/<name>/disko.nix` with the disk layout
3. Create `hosts/<name>/default.nix` importing the shared profiles
4. Add `<name> = mkNixos "<name>";` to `flake.nix`

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
| Wallpaper | swaybg |
| Clipboard | wl-clipboard |

---

## Tooling

| Tool | Purpose |
|------|---------|
| disko | Declarative disk partitioning |
| deploy-rs | Incremental remote deployment |
| nixos-anywhere | Fresh installs over SSH |

Dev shell (`nix develop`) provides: `deploy-rs`, `nixos-anywhere`, `nixd`, `statix`, `deadnix`.

---

## Validation

```bash
nix flake check
nix build '.#nixosConfigurations.vm.config.system.build.toplevel' --no-link
```
