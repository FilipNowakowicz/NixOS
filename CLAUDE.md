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
- **Hot-reload:** `ssh nixvm 'DISPLAY=:0 hyprctl reload'`
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

Migrating from AwesomeWM (X11) to Hyprland (Wayland) with Waybar.
The `home/files/awesome/` directory is being replaced — do not
spend time adapting or fixing it.
VM host needs creating — virtio config currently lives in main,
needs extracting into hosts/vm/.

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
| Launcher | Rofi-wayland |
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
- Clean separation between vm and main host configs

---

## Preferences

- Incremental changes — don't refactor everything at once
- Ask before making large structural changes
- Prefer home-manager for user-level config over system-level
- Keep things declarative — avoid imperative workarounds
- Flag anything that might cause issues on rebuild
