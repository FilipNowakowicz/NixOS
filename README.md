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
- The VM and homeserver use impermanence: root is ephemeral, persistent state lives on `/persist`.
- Secrets are managed with sops-nix and age encryption.

---

## Repository Structure

```
.
├── flake.nix                          # Entry point: hosts, shells, deploy-rs, disko, VM apps
├── flake.lock
├── .sops.yaml                         # age key groups for sops secret encryption
├── hosts
│   ├── main                           # Primary workstation
│   ├── homeserver                     # Headless server (Tailscale, Vaultwarden, Syncthing)
│   ├── vm                             # QEMU/KVM test VM
│   └── installer                      # Minimal NixOS ISO for fresh installs
├── modules
│   └── nixos/profiles
│       ├── base.nix                   # Nix settings, locale, zsh, essentials
│       ├── desktop.nix                # Hyprland, pipewire, portals, fonts
│       └── security.nix               # Firewall, sshd, sysctl hardening
└── home
    ├── profiles
    │   ├── base.nix                   # CLI tools, zsh, git, starship, fzf, zoxide
    │   └── desktop.nix                # GUI packages, GTK, cursor, mako, waybar
    ├── theme/colors.nix               # Gruvbox-warm palette (single source of truth)
    ├── users/user/home.nix            # User entry point: git, zsh aliases, dotfile wiring
    └── files                          # Dotfiles (Hyprland, Kitty, Neovim)
```

---

## Hosts

| Host | Description |
|------|-------------|
| `main` | Primary workstation, running a full desktop environment. |
| `homeserver` | Headless server for self-hosted services. |
| `vm` | Ephemeral QEMU/KVM test VM for development and testing. |
| `installer` | Minimal ISO configuration used to bootstrap new installations. |

### Deployment

| Host | Command | Notes |
|---|---|---|
| `main` | `sudo nixos-rebuild switch --flake .#main` | Run locally on the machine. |
| `homeserver` | `deploy .#homeserver` | Run from the `nix develop` shell on the dev machine. |
| `vm` | `deploy .#vm` | Run from the `nix develop` shell on the dev machine. |


## Services (Homeserver)

The `homeserver` is configured to run the following services:

| Service | Purpose | Access |
|---|---|---|
| **Tailscale** | Zero-config VPN for secure remote access. | Connect from any Tailscale client. |
| **Vaultwarden** | Self-hosted Bitwarden-compatible password manager. | `https://homeserver` (via Tailscale) |
| **Syncthing** | Continuous, peer-to-peer file synchronization. | `http://homeserver:8384` (via Tailscale) |

---

## Secrets (sops-nix)

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) and [age](https://age-encryption.org) encryption.

### How it works

- `.sops.yaml` defines rules for which age public keys can decrypt which secret files.
- Keys are grouped by name (e.g., `&user`, `&vm_host`, `&homeserver_host`).
- Host keys (`vm_host`, `homeserver_host`) are derived from their respective SSH host public keys using `ssh-to-age`.
- This allows a host to decrypt its own secrets automatically during activation.
- The user's personal age key (`user`) can decrypt all secrets.

### Setup

1. **Generate your personal age key** (once):
   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt
   ```
   Add the public key to `.sops.yaml` under the `&user` anchor.

2. **Add a host's age key** after its first boot:
   On the new host, get its SSH public key, convert it to an age key, and add it to `.sops.yaml`.
   ```bash
   # On the new host (e.g., homeserver)
   cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age

   # On your dev machine, add the resulting age key to .sops.yaml
   # under a new anchor (e.g., &homeserver_host) and update the
   # creation_rules to give it access to its secrets file.
   ```

3. **Edit secrets:**
   ```bash
   # Edits a file, decrypting it temporarily
   sops hosts/homeserver/secrets/secrets.yaml
   ```

---

## Tooling

The flake provides several `devShells` and `apps` for development and maintenance.

| Type | Name | Purpose |
|------|------|---------|
| `devShell` | `default` | Main dev shell with `deploy-rs`, `nixos-anywhere`, `sops`, etc. |
| `devShell` | `security` | Includes common security tools: `nmap`, `gobuster`, `sqlmap`, `hydra`, `john`, etc. |
| `app` | `reinstall-vm` | Runs `nixos-anywhere` to perform a fresh installation of the VM. |
| `app` | `launch-vm` | Boots the installed VM with QEMU. |
| `app` | `launch-vm-iso`| Boots the installer ISO in the VM to begin a fresh install. |

### Fresh VM Install

The test VM uses an ephemeral root filesystem (impermanence), so its state is reset on every boot. A full re-installation is only needed if the underlying disk layout (`hosts/vm/disko.nix`) is changed.

The process involves:
1.  **One-time setup:** Creating a QEMU disk image and copying UEFI variable storage.
2.  **Building an installer ISO** using the `installer` host configuration.
3.  **Booting the ISO** in the VM using the `.#launch-vm-iso` app.
4.  **Running the installation** from the development shell using the `.#reinstall-vm` app. This app connects to the booted ISO via SSH and uses `nixos-anywhere` to partition the disk and install the `vm` configuration.
5.  **Launching the final VM** with the `.#launch-vm` app and deploying any subsequent changes with `deploy .#vm`.
---

## Desktop Stack

| Layer | Tool |
|---|---|
| Display Manager| greetd (tuigreet) |
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
| System monitor | Btop |

---

## Validation

```bash
# Check for flake inputs, formatting, and unused variables
nix flake check

# Build all host configurations to ensure they evaluate correctly
nix build '.#nixosConfigurations.vm.config.system.build.toplevel' --no-link
nix build '.#nixosConfigurations.main.config.system.build.toplevel' --no-link
nix build '.#nixosConfigurations.homeserver.config.system.build.toplevel' --no-link
```