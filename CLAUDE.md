# NixOS Flake Configuration

Personal NixOS flake for an endgame, reproducible setup.
Prefer clean, idiomatic Nix over quick fixes. Suggest better
approaches proactively. Explain why, not just what.

---

## Environment

- **Dev machine:** NixOS (main)
- **Dev shell:** `nix develop` — provides `deploy-rs`, `nixos-anywhere`, `nh`, `nixd`, `statix`, `deadnix`, `pre-commit`, `sops`, `ssh-to-age`, `qemu`, `OVMF`
- **Per-project shells:** `direnv` enabled — use `use flake` in `.envrc` for automatic environment loading.
- **Deploy (VM):** `deploy '.#vm'` (Note: `homeserver-vm` is managed via `main`'s microvm; QEMU `vm` is for testing only)
- **Deploy (WSL):** `home-manager switch --flake .#user@wsl`
- **Deploy (main):** `nh os switch --hostname main .` (alias: `rebuild`)
- **Validate flake:** `nix flake check`
- **Automated updates:** Weekly `flake.lock` updates (`flake-update.yml`); auto-merges if `merge-gate` status check passes.
- **Merge Gate:** Consolidates all required checks (flake-check, invariants, smoke-tests) into a single required status check for branch protection.
- **Module Topology:** Global profile imports in `modules/nixos/default.nix` have been removed. Hosts must explicitly import required profiles (e.g., `desktop`, `security`).
- **Host Registry:** `lib/hosts.nix` is the single source of truth and uses typed schema validation.
- **Validate invariants:** `nix build '.#checks.x86_64-linux.invariants-<host>'`
- **Validate profile:** `nix build '.#checks.x86_64-linux.profile-<name>'`
- **Golden tests:** `nix build '.#checks.x86_64-linux.lib-generators-golden'`
- **CVE scan:** `nix build '.#checks.x86_64-linux.cve-check-<host>'`
- **Lint:** `statix check .` and `deadnix .`
- **Pre-commit (manual run):** `pre-commit run --all-files`
- **Git** is for version control only, not deployment

---

## VM Management

### homeserver-vm (microvm — primary workflow)

homeserver-vm runs as a systemd service on `main` via microvm.nix.

```bash
nh os switch --hostname main .                       # deploy config changes (starts VM if not running)
sudo systemctl start microvm@homeserver-vm.service   # start manually
sudo systemctl stop microvm@homeserver-vm.service    # stop
sudo journalctl -u microvm@homeserver-vm.service -f  # watch logs
ssh user@10.0.100.2                                  # SSH into VM
```

Services are reachable from main at:

- Vaultwarden: `https://10.0.100.2:8443`
- Syncthing: `http://10.0.100.2:8384`

---

## Networking & VPN

- **Tailscale** — used for secure remote access and service mesh.
- **Tailscale ACLs** — generated declaratively from `lib/hosts.nix`.
  - Tags are assigned per-host in the registry (`tailscale.tag`).
  - Current policy intent is minimal: `lib/acl.nix` consumes only tags and emits broad fleet-wide rules.
  - Richer host metadata like `tailnetFQDN` stays outside the ACL output unless host-specific policy is added deliberately.
  - Build/inspect ACLs: `nix build '.#packages.x86_64-linux.tailscale-acl'`.
- **Tailscale Certs** — `homeserver` uses `tailscale-cert.service` to fetch TLS certificates automatically.

---

### nix run '.#vm' (QEMU — archived)

`scripts/vm.sh` and `nix run '.#vm'` are archived for testing impermanence,
bootloader, and LUKS on main hardware before real deployment. Not used for
homeserver-vm day-to-day.

```bash
nix run '.#vm' -- create <name>   # Full setup (impermanence testing only)
nix run '.#vm' -- start <name>    # Launch existing VM
nix run '.#vm' -- ssh <name>      # SSH into VM
```

**VM registry** (`lib/hosts.nix`) is the single source of truth for all hosts.

---

## Repository Structure

- `flake.nix` — entry point, defines hosts, home-manager, deploy-rs nodes, VM app
- `lib/hosts.nix` — host registry (single source of truth for all hosts)
- `lib/generators.nix` — typed Alloy HCL generators
- `lib/dashboards.nix` — typed Grafana dashboard builders
- `lib/invariants.nix` — configuration invariant check builders
- `lib/cve-checks.nix` — CVE scanning check builders
- `lib/acl.nix` — Tailscale ACL generator (derives rules from host registry)
- `lib/pubkeys.nix` — centralized SSH public keys
- `lib/syncthing.nix` — shared Syncthing device/folder registry
- `lib/network.nix` — centralized network identifiers (tailnet FQDN)
- `hosts/main/` — real machine config, disko layout, LUKS/LVM, Lanzaboote (Secure Boot)
- `hosts/vm/` — dev/test VM config (desktop profile + home-manager)
- `hosts/homeserver-vm/` — homeserver services in a VM (Vaultwarden, Syncthing)
- `hosts/homeserver/` — real hardware homeserver (same services + Tailscale, Nginx, TLS)
- `hosts/installer/` — minimal NixOS ISO config for fresh installs
- `scripts/vm.sh` — unified VM management script
- `scripts/closure-diff.sh` — compute closure diffs in CI
- `scripts/reinstall-homeserver.sh` — real homeserver reinstall (separate workflow)
- `modules/nixos/microvms/` — microvm.nix VM definitions (homeserver-vm)
- `modules/nixos/profiles/` — system profiles (base, desktop, security, observability, vm, sops-base)
- `modules/nixos/services/` — standalone systemd services (hardened.nix, failure-notify)
- `modules/nixos/hardware/` — hardware drivers and graphics (NVIDIA PRIME)
- `home/profiles/` — home-manager profiles (base, desktop, workstation)
- `home/theme/` — runtime-swappable themes and Home Manager module
  - `active.nix` is intentionally local state (tracks current theme). On a fresh clone, run:
    `git update-index --skip-worktree home/theme/active.nix`
    To commit a new default: `git update-index --no-skip-worktree home/theme/active.nix`, commit, re-apply.
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
- **.sops.yaml:** repo root, defines key groups per path regex
- **Initrd Secrets:** `boot.initrd.secrets` MUST only point to sops-managed paths (e.g., `config.sops.secrets.X.path`). This is enforced by an invariant check.
- **vm host:** has its own SSH host key in `hosts/vm/secrets/` — injected during `create`/`reinstall`

- **homeserver-vm:** uses a dedicated age key stored in main's sops secrets (`hosts/main/secrets/secrets.yaml`), injected into the VM via virtiofs at `/run/age-keys/`

- **Homeserver Bootstrap:** Real hardware reinstall requires pre-baked host keys in `hosts/homeserver/secrets/` to ensure the host has a stable age identity from first boot. If missing, the `homeserver-sops-bootstrap` invariant check will fail.
  1. Generate key: `ssh-keygen -t ed25519 -f /tmp/hs_key -N ""`
  2. Encrypt: `sops encrypt --input-type binary --output-type binary --output hosts/homeserver/secrets/ssh_host_ed25519_key.enc /tmp/hs_key`
  3. Encrypt pubkey: `sops encrypt --input-type binary --output-type binary --output hosts/homeserver/secrets/ssh_host_ed25519_key.pub.enc /tmp/hs_key.pub`
  4. Update `.sops.yaml` with the new age key and run `sops updatekeys hosts/homeserver/secrets/secrets.yaml`.

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
