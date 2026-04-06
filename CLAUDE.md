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
- **Deploy (main):** `nixos-rebuild switch --flake .#main`
- **Hot-reload:** `ssh nixvm 'hyprctl reload'`
- **Launch VM:** `nix run '.#launch-vm'`
- **Git** is for version control only, not deployment

### Fresh VM install

The VM uses impermanence — a fresh install is required whenever the disk layout changes.

1. Create disk image (if not already present):
   `qemu-img create -f qcow2 /vmstore/images/nixos-test.qcow2 40G`
2. Copy OVMF vars (if not already present):
   `cp /usr/share/OVMF/x64/OVMF_VARS.4m.fd /vmstore/images/nixos-test-vars.fd`
3. Build the installer ISO:
   `nix build '.#packages.x86_64-linux.installer-iso'`
4. Boot the ISO in the VM:
   `nix run '.#launch-vm-iso' -- result/iso/*.iso`
5. From the Arch host dev shell, install:
   `nixos-anywhere --flake '.#vm' root@nixvm`
   - nixos-anywhere SSHes into the live ISO, runs disko to partition `/dev/vda`, installs NixOS, reboots
6. After reboot, launch the VM normally: `nix run '.#launch-vm'`
7. Deploy updates: `deploy .#vm`

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

- Neovim theming from colors.nix
- Multi-monitor support via Hyprland

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

- Neovim theming (in progress)
- Multi-monitor support via Hyprland

---

## Preferences

- Incremental changes — don't refactor everything at once
- Ask before making large structural changes
- Prefer home-manager for user-level config over system-level
- Keep things declarative — avoid imperative workarounds
- Flag anything that might cause issues on rebuild
- Run `nix flake check` and `nix build '.#nixosConfigurations.vm.config.system.build.toplevel' --no-link` after changes to `.nix` files — skip for documentation or dotfile/config edits
