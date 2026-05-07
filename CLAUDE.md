# NixOS Flake Configuration

Personal NixOS flake for an endgame, reproducible setup.
Prefer clean, idiomatic Nix over quick fixes. Suggest better
approaches proactively. Explain why, not just what.

---

## Environment

- **Dev machine:** NixOS (main)
- **Dev shell:** `nix develop` — provides `deploy-rs`, `nixos-anywhere`, `nixd`, `statix`, `deadnix`, `sops`, `ssh-to-age`, `qemu`, `OVMF`, `vulnix`, `direnv`, and the flake-managed pre-commit hook tooling.
- **Per-project shells:** `direnv` enabled — use `use flake` in `.envrc` for automatic environment loading.
- **Deploy (VM):** `deploy '.#vm'` (QEMU `vm` is legacy-supported testing only)
- **Deploy (WSL):** `home-manager switch --flake .#user@wsl`
- **Deploy (main):** `nh os switch --hostname main .` (alias: `rebuild`)
- **Validate flake eval:** `bash scripts/validate.sh flake-eval`
- **Automated updates:** Weekly `flake.lock` updates (`flake-update.yml`); auto-merges if `merge-gate` status check passes.
- **Merge Gate:** Consolidates all required checks (flake-check, invariants, smoke-tests) into a single required status check for branch protection.
- **Module Topology:** `modules/nixos/default.nix` globally imports `profiles/observability/`, `profiles/backup.nix`, `services/systemd-failure-notify.nix`, and `services/hardened.nix` for all hosts. Hosts must explicitly import host-specific profiles (e.g., `desktop`, `security`, `base`) but must NOT re-import the globally-provided ones.
- **Host Registry:** `lib/hosts.nix` is the single source of truth and uses typed schema validation. It includes target architecture (`system`) for multi-arch support.
- **Validate light CI suite:** `bash scripts/validate.sh light`
- **Validate hosts:** `bash scripts/validate.sh hosts`
- **Validate profile tests:** `bash scripts/validate.sh profile-tests`
- **Validate heavy suite:** `bash scripts/validate.sh heavy`
- **Golden tests:** `nix build '.#checks.x86_64-linux.lib-generators-golden'`
- **CVE scan:** `bash scripts/validate.sh cve-reports`
- **Lint:** `statix check .` and `deadnix .`
- **Pre-commit (manual run):** `pre-commit run --all-files`
- **Git hooks:** `nix develop` installs a `commit-msg` hook that removes `Co-authored-by:` trailers to keep history single-author.
- **Git** is for version control only, not deployment

---

## VM Management

### nix run '.#vm' (QEMU — legacy-supported)

- **Tailscale** — used for secure remote access and service mesh.
- **Tailscale ACLs** — generated declaratively from `lib/hosts.nix`.
  - Tags are assigned per-host in the registry (`tailscale.tag`).
  - Current policy intent is explicit: `lib/acl.nix` consumes tags, `acceptFrom`, and `tailnetFQDN` when host-specific policy is needed.
  - Richer host metadata like `ip` and `backup.class` stays outside the ACL output unless host-specific policy is added deliberately.
  - Build/inspect ACLs: `nix build '.#packages.x86_64-linux.tailscale-acl'`.
- **Tailscale Certs** — `homeserver-gcp` uses `tailscale-cert.service` to fetch TLS certificates automatically.

`scripts/vm.sh` and `nix run '.#vm'` are archived for testing impermanence,
bootloader, and LUKS on main hardware before real deployment.

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
- `docs/architecture.md` — structural rules and module boundaries
- `docs/operations.md` — deployment, VM workflows, and validation runbook
- `docs/security.md` — secrets, exposure, and hardening model
- `hosts/main/` — real machine config, disko layout, LUKS/LVM, Lanzaboote (Secure Boot)
- `hosts/vm/` — dev/test VM config (desktop profile + home-manager)
- `hosts/homeserver-gcp/` — GCP homeserver (Vaultwarden, Syncthing, LGTM, Nginx, Tailscale, TLS)
- `hosts/installer/` — minimal NixOS ISO config for fresh installs
- `scripts/vm.sh` — legacy-supported QEMU VM management script
- `scripts/closure-diff.sh` — compute closure diffs in CI
- `modules/nixos/profiles/` — system profiles (base, desktop, security, observability, observability-client, vm, sops-base)
- `modules/nixos/services/` — standalone systemd services (hardened.nix, failure-notify)
- `modules/nixos/hardware/` — hardware drivers and graphics (NVIDIA PRIME)
- `home/profiles/` — home-manager profiles (base, desktop, workstation)
- `home/theme/` — runtime-swappable themes and Home Manager module
  - `active.nix` is intentionally local state (tracks current theme). On a fresh clone, run:
    `git update-index --skip-worktree home/theme/active.nix`
    To commit a new default: `git update-index --no-skip-worktree home/theme/active.nix`, commit, re-apply.
- `home/files/` — dotfiles and standalone scripts (NIX_REPO injected)
- `home/users/user/` — user home-manager entry points (`home.nix`, `server.nix`, `wsl.nix`)
- `templates/python/` — reusable Python dev shell template (`nix flake init -t ~/nix#python`); provides python3, uv, ruff, basedpyright; sets `UV_PYTHON_DOWNLOADS=never` and `UV_PYTHON` to pin Python to nixpkgs

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

---

## Goals

See [docs/goals.md](./docs/goals.md) for the full project roadmap and in-progress tasks.

---

## Security Preferences

- **Passwordless sudo is for VMs/dev machines and `machine-common` hosts only.**
- **Interactive access should rely on SSH keys.** Host user password hashes are still managed through sops where declared for login/recovery compatibility.
- **Scope secrets appropriately.** Each host should only be able to decrypt
  the secrets it needs, as defined in `.sops.yaml`.

---

## Preferences

- Incremental changes — don't refactor everything at once
- Ask before making large structural changes
- Prefer home-manager for user-level config over system-level
- Keep things declarative — avoid imperative workarounds
- Flag anything that might cause issues on rebuild
- Validate only what you changed: if VM config changed build `vm-ci`, if `main` changed build `main-ci`, if `homeserver-gcp` changed build its closure, if shared profiles changed build all affected hosts
