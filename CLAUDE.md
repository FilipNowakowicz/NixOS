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
- **Launch VM:** `qemu-system-x86_64 -enable-kvm -machine q35 -cpu host -smp 4 -m 8G -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/x64/OVMF_CODE.4m.fd -drive if=pflash,format=raw,file=/vmstore/images/nixos-test-vars.fd -drive file=/vmstore/images/nixos-test.qcow2,if=virtio -boot menu=on -netdev user,id=net0,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=net0 -daemonize -display none`
- **Git** is for version control only, not deployment

### Fresh VM install

1. Create empty disk image: `qemu-img create -f qcow2 /vmstore/images/nixos-test.qcow2 40G`
2. Boot the NixOS minimal ISO in the VM (add `-cdrom nixos.iso` to the launch command)
3. From the Arch host dev shell: `nixos-anywhere --flake '.#vm' root@nixvm`
   - nixos-anywhere SSHes into the live ISO, runs disko to partition `/dev/vda`, installs NixOS, reboots
4. After reboot, deploy updates normally: `deploy .#vm`

---

## Repository Structure

- `flake.nix` — entry point, defines hosts, home-manager, deploy-rs nodes
- `hosts/main/` — real machine config, hardware drivers, disko layout
- `hosts/vm/` — VM config, virtio drivers, disko layout, used for testing
- `modules/nixos/profiles/` — system profiles (base, desktop, security)
- `home/profiles/` — home-manager profiles (base, desktop)
- `home/files/` — dotfiles managed via home-manager
- `home/users/user/` — user home-manager entry point

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
- nixos-generators for image/ISO generation

---

## Preferences

- Incremental changes — don't refactor everything at once
- Ask before making large structural changes
- Prefer home-manager for user-level config over system-level
- Keep things declarative — avoid imperative workarounds
- Flag anything that might cause issues on rebuild
- Run `nix flake check` and `nix build '.#nixosConfigurations.vm.config.system.build.toplevel' --no-link` after changes to `.nix` files — skip for documentation or dotfile/config edits
