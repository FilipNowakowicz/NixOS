# NixOS Flake Configuration

Personal NixOS flake for an endgame, reproducible setup.
Prefer clean, idiomatic Nix over quick fixes. Suggest better
approaches proactively. Explain why, not just what.

---

## Environment

- **Dev machine:** Arch Linux
- **Target:** NixOS VM via `ssh nixvm` (~/.ssh/config alias on Arch)
- **Deploy (VM):** `deploy .#vm` (requires `nix develop` or direnv to load the dev shell)
- **Deploy (main):** `nixos-rebuild switch --flake .#main`
- **Hot-reload:** `ssh nixvm 'hyprctl reload'`
- **Dev shell:** `nix develop` — provides `deploy-rs`, `nixd`, `statix`, `deadnix`
- **Launch VM:** `qemu-system-x86_64 -enable-kvm -machine q35 -cpu host -smp 4 -m 8G -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/x64/OVMF_CODE.4m.fd -drive if=pflash,format=raw,file=/vmstore/images/nixos-test-vars.fd -drive file=/vmstore/images/nixos-test.qcow2,if=virtio -boot menu=on -netdev user,id=net0,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=net0 -daemonize -display none`
- **Git** is for version control only, not deployment

---

## Repository Structure

- `flake.nix` — entry point, defines hosts and home-manager
- `hosts/main/` — real machine config, standard hardware drivers
- `hosts/vm/` — VM config, virtio drivers, used for testing
- `modules/nixos/profiles/` — system profiles (base, desktop, security)
- `home/profiles/` — home-manager profiles (base, desktop)
- `home/files/` — dotfiles managed via home-manager
- `home/users/user/` — user home-manager entry point

---

## Current Focus

Core Hyprland migration done. Remaining app configs to complete:
Mako (colors + position), Hyprlock, Neovim theming, Starship prompt.
Multi-monitor support not yet configured.

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
| Wallpaper | Hyprpaper |
| Clipboard | wl-clipboard |
| System monitor | Btop |

---

## Goals

- Hyprland migration ✓
- Waybar config + theme ✓
- Kitty config + theme ✓
- Zsh via programs.zsh with nix-managed plugins ✓
- Rofi config + theme ✓
- Hyprpaper + wallpaper in repo ✓
- Clean separation between vm and main host configs ✓
- Individual app configs — Mako, Hyprlock, Starship, Neovim theming (in progress)
- Multi-monitor and multi-device support via Hyprland
- disko for declarative disk partitioning
- nixos-generators for image/ISO generation
- deploy-rs for declarative remote deployments ✓

---

## Preferences

- Incremental changes — don't refactor everything at once
- Ask before making large structural changes
- Prefer home-manager for user-level config over system-level
- Keep things declarative — avoid imperative workarounds
- Flag anything that might cause issues on rebuild
- Run `nix flake check` and `nix build '.#nixosConfigurations.vm.config.system.build.toplevel' --no-link` after changes to `.nix` files — skip for documentation or dotfile/config edits
