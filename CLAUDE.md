# NixOS Flake Configuration

Personal NixOS flake for an endgame, reproducible setup.
Prefer clean, idiomatic Nix over quick fixes. Suggest better
approaches proactively. Explain why, not just what.

---

## Environment

- **Dev machine:** Arch Linux
- **Target:** NixOS VM via `ssh nixvm` (~/.ssh/config alias on Arch)
- **Deploy (VM):** `nixos-rebuild switch --flake .#vm --target-host nixvm --use-remote-sudo`
- **Deploy (main):** `nixos-rebuild switch --flake .#main`
- **Hot-reload:** `ssh nixvm 'hyprctl reload'`
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

Hyprland migration in progress. System and home profiles have been
converted to Wayland — base hyprland.conf exists with dvorak input
and keybindings. Next: individual app configs (Waybar, Hyprlock,
Hyprpaper, Mako, Rofi, Kitty, Neovim, etc.).

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

- Hyprland migration (in progress)
- Individual app configs (Waybar, Kitty, Neovim, Zsh, Rofi, etc.)
- Multi-monitor and multi-device support via Hyprland
- Clean separation between vm and main host configs ✓
- disko for declarative disk partitioning
- nixos-generators for image/ISO generation

---

## Preferences

- Incremental changes — don't refactor everything at once
- Ask before making large structural changes
- Prefer home-manager for user-level config over system-level
- Keep things declarative — avoid imperative workarounds
- Flag anything that might cause issues on rebuild
- Always validate changes by running `nix build '.#nixosConfigurations.vm.config.system.build.toplevel' --no-link` before considering a task done
