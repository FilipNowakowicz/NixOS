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
- The VM uses impermanence: root is ephemeral, persistent state lives on `/persist`.
- Secrets are managed with sops-nix and age encryption.

---

## Repository Structure

```
.
├── flake.nix                          # Entry point: hosts, home-manager, deploy-rs, disko, VM apps
├── flake.lock
├── .sops.yaml                         # age key groups for sops secret encryption
├── hosts
│   ├── main
│   │   ├── default.nix                # Primary machine config
│   │   ├── disko.nix                  # Declarative disk layout (/dev/nvme0n1)
│   │   └── hardware-configuration.nix
│   ├── vm
│   │   ├── default.nix                # QEMU/KVM VM config (impermanence, sops)
│   │   ├── disko.nix                  # /boot (512M) + / (8G) + /persist (remaining)
│   │   ├── hardware-configuration.nix
│   │   └── secrets
│   │       └── secrets.yaml           # sops-encrypted secrets
│   └── installer
│       └── default.nix                # Minimal NixOS ISO for fresh installs
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

The VM uses impermanence — root is wiped on every reboot, state is persisted to `/persist`.
A fresh install is required whenever the disk layout changes.

```bash
# 1. Create disk image (once)
qemu-img create -f qcow2 /vmstore/images/nixos-test.qcow2 40G

# 2. Copy OVMF vars (once — must be writable for UEFI state)
cp /usr/share/OVMF/x64/OVMF_VARS.4m.fd /vmstore/images/nixos-test-vars.fd

# 3. Build the installer ISO
nix build '.#packages.x86_64-linux.installer-iso'

# 4. Boot the ISO in the VM
nix run '.#launch-vm-iso' -- result/iso/*.iso

# 5. From the Arch host dev shell, reinstall
nix develop
nix run '.#reinstall-vm'
# - Clears the stale SSH host key from ~/.ssh/known_hosts
# - Decrypts the VM's SSH host keys from sops secrets and injects them so
#   the age identity is stable from first boot (required for sops decryption)
# - Runs nixos-anywhere with --no-substitute-on-destination (copies store
#   paths locally instead of downloading from cache.nixos.org)
# - Partitions /dev/vda via disko, installs NixOS, reboots

# 6. After reboot, launch normally
nix run '.#launch-vm'

# 7. Deploy updates
deploy .#vm
```

---

## Secrets

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) and [age](https://age-encryption.org) encryption.

### Setup

1. **Generate your age key** on the Arch host (once):
   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt
   ```
   Add the public key to `.sops.yaml` under `&user`.

2. **Get the VM host age key** after a fresh install:
   ```bash
   ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
   ```
   Add the output to `.sops.yaml` under `&vm_host`.

3. **Edit secrets:**
   ```bash
   sops hosts/vm/secrets/secrets.yaml
   ```

### How it works

- `.sops.yaml` defines which age keys can decrypt which secret files.
- The VM's SSH host key (`/etc/ssh/ssh_host_ed25519_key`) is persisted via impermanence so the age identity survives reboots.
- sops-nix decrypts secrets at activation time and exposes them as files owned by root (or a specified user).

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
| impermanence | Ephemeral root with explicit persistence |
| sops-nix | Secrets management with age encryption |
| ssh-to-age | Convert SSH host key to age identity |

Dev shell (`nix develop`) provides: `deploy-rs`, `nixos-anywhere`, `nixd`, `statix`, `deadnix`.

---

## Validation

```bash
nix flake check
nix build '.#nixosConfigurations.vm.config.system.build.toplevel' --no-link
```
