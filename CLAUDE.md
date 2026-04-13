# NixOS Flake Configuration

Personal NixOS flake for an endgame, reproducible setup.
Prefer clean, idiomatic Nix over quick fixes. Suggest better
approaches proactively. Explain why, not just what.

---

## Environment

- **Dev machine:** NixOS (main)
- **Dev shell:** `nix develop` — provides `deploy-rs`, `nixos-anywhere`, `nh`, `nixd`, `statix`, `deadnix`, `sops`, `ssh-to-age`
- **Deploy (VM):** `deploy .#vm`
- **Deploy (main):** `nh os switch --hostname main .` (alias: `rebuild`)
- **Validate flake:** `nix flake check`
- **Lint:** `statix check .` and `deadnix .`
- **Hot-reload:** `ssh nixvm 'hyprctl reload'`
- **Launch VM:** `nix run '.#launch-vm'`
- **Git** is for version control only, not deployment

---

## Repository Structure

- `flake.nix` — entry point, defines hosts, home-manager, deploy-rs nodes, VM apps
- `hosts/main/` — real machine config, disko layout, LUKS/LVM, Lanzaboote (Secure Boot)
- `hosts/vm/` — VM config, virtio drivers, disko layout, impermanence, sops secrets
- `hosts/installer/` — minimal NixOS ISO config for fresh installs
- `hosts/homeserver/` — homeserver config (Vaultwarden, Nginx, Tailscale)
- `lib/pubkeys.nix` — centralized SSH public keys
- `scripts/` — VM/homeserver bootstrap and reinstall scripts
- `modules/nixos/hardware/` — hardware drivers and graphics (NVIDIA PRIME)
- `modules/nixos/profiles/` — system profiles (base, desktop, security)
- `home/profiles/` — home-manager profiles (base, desktop)
- `home/theme/` — runtime-swappable themes and Home Manager module
- `home/files/` — dotfiles and standalone scripts (NIX_REPO injected)
- `home/users/user/` — user home-manager entry point
- `home/users/user/home.nix` — main user config, imports theme module and scripts

---

## Agents

- Claude Code — all .nix changes, deployments, secrets
- Gemini CLI — documentation only (.md files), consistency checks, README updates

---

## Secrets (sops-nix)

Managed with sops-nix + age. Edit secrets with `sops <file>`.

- **Age key:** `~/.config/sops/age/keys.txt`
- **Adding a host key:** `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub` → add result to `.sops.yaml` under `&vm_host`, `&main_host`, or `&homeserver_host`
- **`.sops.yaml`:** repo root, defines key groups per path regex
- **VM secrets:** `hosts/vm/secrets/secrets.yaml` — host key survives reboots via impermanence

---

## Goals

See [GOALS.md](./GOALS.md) for the full project roadmap and in-progress tasks.

---

## Security Preferences

- **Passwordless sudo is for VMs and dev machines only.**
- **VM and Homeserver users have no password** (rely on SSH keys).
- **Scope secrets appropriately.** Each host should only be able to decrypt
  the secrets it needs, as defined in `.sops.yaml`.

---

## Preferences

- Incremental changes — don't refactor everything at once
- Ask before making large structural changes
- Prefer home-manager for user-level config over system-level
- Keep things declarative — avoid imperative workarounds
- Flag anything that might cause issues on rebuild
- Validate only what you changed: if vm config changed build vm, if main changed build main, if homeserver changed build homeserver, if shared profiles changed build all three
