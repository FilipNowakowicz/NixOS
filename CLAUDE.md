# NixOS Flake Configuration

Personal NixOS flake for an endgame, reproducible setup.
Prefer clean, idiomatic Nix over quick fixes. Suggest better
approaches proactively. Explain why, not just what.

---

## Environment

- **Dev machine:** Arch Linux
- **Target:** NixOS VM via `ssh nixvm` (~/.ssh/config alias on Arch)
- **Dev shell:** `nix develop` — provides `deploy-rs`, `nixos-anywhere`, `nixd`, `statix`, `deadnix`
- **Deploy (VM):** `deploy .#vm`
- **Deploy (main):** `sudo nixos-rebuild switch --flake .#main` (alias: `rebuild`)
- **Hot-reload:** `ssh nixvm 'hyprctl reload'`
- **Launch VM:** `nix run '.#launch-vm'`
- **Git** is for version control only, not deployment

### Fresh VM install

The VM uses impermanence. A fresh install is required whenever the disk layout (`hosts/vm/disko.nix`) changes.

1.  **Create disk image** (if not already present):
    `qemu-img create -f qcow2 /vmstore/images/nixos-test.qcow2 40G`

2.  **Copy OVMF vars** (if not already present):
    `cp /usr/share/OVMF/x64/OVMF_VARS.4m.fd /vmstore/images/nixos-test-vars.fd`

3.  **Build the installer ISO**:
    `nix build '.#packages.x86_64-linux.installer-iso'`

4.  **Boot the ISO in the VM**:
    `nix run '.#launch-vm-iso' -- result/iso/*.iso`

5.  **From the dev shell, run the installation**:
    `nix run '.#reinstall-vm'`
    This script automates the `nixos-anywhere` process:
    - Clears the stale SSH host key from `~/.ssh/known_hosts`.
    - Decrypts the VM's persistent SSH host keys from sops secrets and injects them. This ensures the VM's age identity is stable from the first boot, which is required for it to decrypt its own secrets.
    - Runs `nixos-anywhere` to partition `/dev/vda` (via disko) and install the `vm` configuration from the flake.

6.  **Post-install**: After the installer reboots the VM, launch it normally and deploy any pending changes.
    `nix run '.#launch-vm'`
    `deploy .#vm`

---

## Repository Structure

- `flake.nix` — entry point, defines hosts, home-manager, deploy-rs nodes, VM apps
- `hosts/main/` — real machine config, hardware drivers, disko layout
- `hosts/vm/` — VM config, virtio drivers, disko layout, impermanence, sops secrets
- `hosts/installer/` — minimal NixOS ISO config for fresh installs
- `modules/nixos/profiles/` — system profiles (base, desktop, security)
- `home/profiles/` — home-manager profiles (base, desktop)
- `home/files/` — dotfiles managed via home-manager
- `home/users/user/` — user home-manager entry point

---

## Secrets (sops-nix)

Secrets are managed with sops-nix and age encryption.

- **Age key (Arch host):** `~/.config/sops/age/keys.txt`
  Generate with: `age-keygen -o ~/.config/sops/age/keys.txt`
- **VM host key:** converted from the SSH host key using:
  `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`
  The resulting age pubkey goes into `.sops.yaml` under `&vm_host`
- **`.sops.yaml`:** repo root, defines key groups per path regex
- **Secrets file:** `hosts/vm/secrets/secrets.yaml` — encrypted, edit with `sops hosts/vm/secrets/secrets.yaml`
- The VM's `/etc/ssh/ssh_host_ed25519_key` is persisted via impermanence so the host key (and thus the age decryption key) survives reboots

---

## Current Focus


---

## Stack

| Layer | Tool |
|---|---|
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

## Goals

### Homeserver
- Deploy onto old laptop via nixos-anywhere (replace hardware-configuration.nix stub)
- Add sops-nix + impermanence to homeserver config
- Bring up Tailscale
- Bring up Syncthing
- Bring up Vaultwarden

### UI (Deferred)
- Waybar redesign (thinner bar, pill modules, weather)
- eww floating widgets (clock, weather, Spotify, WiFi, Bluetooth, brightness)

### Low Priority
- Lanzaboote (main hardware only)
---

## Preferences

- Incremental changes — don't refactor everything at once
- Ask before making large structural changes
- Prefer home-manager for user-level config over system-level
- Keep things declarative — avoid imperative workarounds
- Flag anything that might cause issues on rebuild
- Run `nix flake check` and `nix build '.#nixosConfigurations.vm.config.system.build.toplevel' --no-link` after changes to `.nix` files — skip for documentation or dotfile/config edits
- When commiting do not add co-authorship
- Never push commits
