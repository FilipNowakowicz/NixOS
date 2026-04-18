# NixOS Flake Configuration

Personal NixOS flake for an endgame, reproducible setup.
Prefer clean, idiomatic Nix over quick fixes. Suggest better
approaches proactively. Explain why, not just what.

---

## Environment

- **Dev machine:** NixOS (main)
- **Dev shell:** `nix develop` — provides `deploy-rs`, `nixos-anywhere`, `nh`, `nixd`, `statix`, `deadnix`, `sops`, `ssh-to-age`, `qemu`, `OVMF`
- **Deploy (VM):** `deploy '.#vm'` or `deploy '.#homeserver-vm'`
- **Deploy (WSL):** `home-manager switch --flake .#user@wsl`
- **Deploy (main):** `nh os switch --hostname main .` (alias: `rebuild`)
- **Validate flake:** `nix flake check`
- **Lint:** `statix check .` and `deadnix .`
- **Git** is for version control only, not deployment

---

## VM Management

All VMs are managed through a single unified command:

```bash
nix run '.#vm' -- <action> <name>
```

| Action | Description |
|--------|-------------|
| `create <name>` | Full setup: disk + ISO + nixos-anywhere + boot |
| `start <name>` | Launch existing VM |
| `stop <name>` | Graceful shutdown |
| `reinstall <name>` | Wipe and reinstall |
| `destroy <name>` | Delete all VM artifacts |
| `ssh <name>` | SSH into the VM |
| `list` | Show all VMs with status |
| `init <name>` | Generate sops secrets for a new VM |

**VM registry** (`lib/vm.nix`) is the single source of truth — SSH ports, disk sizes, deploy-rs nodes, and QEMU config are all derived from it.

**Shared VM module** (`modules/nixos/profiles/vm.nix`) provides hardware, disko, impermanence base, passwordless sudo, and SSH for all VMs.

---

## Repository Structure

- `flake.nix` — entry point, defines hosts, home-manager, deploy-rs nodes, VM app
- `lib/vm.nix` — VM registry (single source of truth for all VMs)
- `lib/pubkeys.nix` — centralized SSH public keys
- `lib/syncthing.nix` — shared Syncthing device/folder registry
- `lib/sandbox.nix` — common systemd service sandbox options
- `lib/network.nix` — centralized network identifiers (tailnet FQDN)
- `hosts/main/` — real machine config, disko layout, LUKS/LVM, Lanzaboote (Secure Boot)
- `hosts/vm/` — dev/test VM config (desktop profile + home-manager)
- `hosts/homeserver-vm/` — homeserver services in a VM (Vaultwarden, Syncthing)
- `hosts/homeserver/` — real hardware homeserver (same services + Tailscale, Nginx, TLS)
- `hosts/installer/` — minimal NixOS ISO config for fresh installs
- `scripts/vm.sh` — unified VM management script
- `scripts/reinstall-homeserver.sh` — real homeserver reinstall (separate workflow)
- `modules/nixos/profiles/` — system profiles (base, desktop, security, observability, vm)
- `modules/nixos/hardware/` — hardware drivers and graphics (NVIDIA PRIME)
- `home/profiles/` — home-manager profiles (base, desktop, workstation)
- `home/theme/` — runtime-swappable themes and Home Manager module
- `home/files/` — dotfiles and standalone scripts (NIX_REPO injected)
- `home/users/user/` — user home-manager entry points (`home.nix`, `server.nix`, `wsl.nix`)

---

## Agents

- Claude Code — all .nix changes, deployments, secrets
- Gemini CLI — documentation only (.md files), consistency checks, README updates

---

## Secrets (sops-nix)

Managed with sops-nix + age. Edit secrets with `sops <file>`.

- **Age key:** `~/.config/sops/age/keys.txt`
- **Adding a host key:** `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub` → add result to `.sops.yaml`
- **`.sops.yaml`:** repo root, defines key groups per path regex
- **Each VM has its own host key** in `hosts/<name>/secrets/` — encrypted host keys are injected during `create`/`reinstall` so sops works from first boot

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
