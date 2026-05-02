# NixOS & Home Manager Flake

A single, reproducible NixOS & Home Manager flake designed as a scalable, long-term setup.
The repository separates hardware, host identity, system profiles, and user configuration to support multiple machines and VMs.

---

## Overview

- **Reproducible & Declarative**: NixOS defines the entire system state, services, and hardware. Home Manager manages the user environment and dotfiles.
- **Multi-Host Ready**: Built from reusable profiles to support a primary workstation (`main`), a headless `homeserver`, a QEMU test VM, and a microvm-based homeserver development target. The host registry defines the target architecture (`system`) per host; the current fleet is `x86_64-linux`.
- **Secrets Management**: Handled by [sops-nix](https://github.com/Mic92/sops-nix) with age encryption, with secrets decrypted at boot by the host itself.
- **Impermanent Root**: VMs and the `homeserver` use an ephemeral root filesystem created with [impermanence](https://github.com/nix-community/impermanence). System state is reset on boot, with persistent data explicitly stored on a `/persist` volume; the real `homeserver` now places that volume inside LUKS.
- **Declarative Disks**: Disk layouts for real hosts and the QEMU test VM are managed declaratively with [disko](https://github.com/nix-community/disko). The `homeserver-vm` microvm uses a `microvm.nix` volume for `/persist`.
- **Runtime Theming**: A runtime-swappable color system allows changing themes without a full NixOS rebuild.

---

## Documentation Map

- [Architecture](docs/architecture.md) - layer boundaries, global imports, host registry rules, and the microvm split.
- [Operations](docs/operations.md) - deployment, VM workflows, homeserver bootstrap, validation, and formatting commands.
- [Security Model](docs/security.md) - sops recipients, initrd SSH, Tailscale exposure, USBGuard, hardening, and backups.
- [Config Dashboard](docs/config-dashboard.md) - plan for evolving the generated inventory into an operator dashboard.
- [Backlog](docs/backlog.md) and [Goals](docs/goals.md) - deferred and active work.
- [Superpowers Design Records](docs/superpowers/README.md) - historical specs and implementation plans.

---

## Secure Boot & Encryption for `main`

The `main` host uses a secure, encrypted systemd-boot setup:

- **Bootloader**: [Lanzaboote](https://github.com/nix-community/lanzaboote) manages Secure Boot, signing a unified kernel image.
- **Disk Encryption**: LUKS encrypts the entire disk.
- **TPM Unlocking**: The system's TPM 2.0 is used to automatically unlock the LUKS-encrypted disk on boot.
- **Hardware Pass-through**: IOMMU is enabled (`intel_iommu=on iommu=force`) for potential VM GPU pass-through.
- **Graphics Drivers**: The configuration uses stable by-path device paths for `AQ_DRM_DEVICES` to ensure stable multi-GPU / monitor performance.
- **Initrd SSH Recovery**: In case of TPM failure, an initrd SSH server (port 2222) is available for remote LUKS unlocking using the dedicated recovery key stored in `lib/recovery-pubkeys.nix`.
  - **Recovery Procedure**:
    1. Retrieve the `id_ed25519_recovery` private key from offline storage.
    2. Connect the host via wired Ethernet (WiFi is unavailable in stage 1).
    3. `ssh -i /path/to/id_ed25519_recovery -p 2222 root@<host-ip>`
    4. Enter the LUKS passphrase when prompted to unlock the disk.
    5. The system will continue booting into stage 2.
  - **Rotation Expectation**: Rotate recovery access by updating `lib/recovery-pubkeys.nix` and redeploying `main`; keep the private key offline and separate from day-to-day SSH credentials.

---

## Features

- **Runtime Theming**: A runtime-swappable color system allows changing themes without a full NixOS rebuild.
- **USB Device Control**: USBGuard enabled on `main` with a strict deny-default policy; only the primary mouse (Logitech receiver) is whitelisted by ID.
- **Tailscale ACLs as Nix**: Security rules and tag owners are generated declaratively from the host registry, providing a single source of truth for network access control.
- **Systemd Hardening**: A custom DSL (`services.hardened`) applies a high-security sandbox baseline to critical services (Vaultwarden, Nginx, Syncthing).
- **Intrusion Prevention**: Fail2ban integrated into the security profile with automated E2E testing.
- **Idle Policy (desktop)**: Hypridle locks at 10 minutes of inactivity and suspends at 15 minutes.
- **Centralized Keys**: Normal SSH public keys live in `lib/pubkeys.nix`; initrd recovery-only keys live in `lib/recovery-pubkeys.nix`.
- **Shared SSH Agent**: Home Manager runs a single user `ssh-agent` service; shells use one shared socket, so loaded keys are reused across terminals.

---

## Repository Structure

```
.
├── flake.nix                          # Flake entry point
├── .sops.yaml                         # SOPS configuration for secret management
├── docs/
│   ├── architecture.md                 # Structural rules and module boundaries
│   ├── operations.md                   # Deployment and validation runbook
│   ├── security.md                     # Secrets, exposure, and hardening model
│   ├── backlog.md                      # Deferred work
│   └── superpowers/                    # Historical specs and implementation plans
├── lib/
│   ├── hosts.nix                      # Host registry (typed schema; single source of truth for all hosts)
│   ├── generators.nix                 # Typed Alloy HCL generators
│   ├── dashboards.nix                 # Typed Grafana dashboard builders
│   ├── invariants.nix                 # Configuration invariant check builders
│   ├── cve-checks.nix                 # CVE scanning check builders
│   ├── pubkeys.nix                    # Standard SSH public keys
│   ├── recovery-pubkeys.nix           # Initrd recovery-only SSH public keys
│   ├── syncthing.nix                  # Shared Syncthing device/folder registry
│   └── acl.nix                        # Declarative Tailscale ACL generator
├── hosts/
│   ├── main/                          # Primary workstation
│   │   ├── default.nix
│   │   ├── disko.nix
│   │   └── hardware-configuration.nix
│   ├── homeserver/                    # Headless server (Vaultwarden, Syncthing, Tailscale)
│   │   ├── default.nix
│   │   ├── disko.nix
│   │   └── hardware-configuration.nix
│   ├── vm/                            # Dev/test VM (desktop + home-manager)
│   │   ├── default.nix
│   │   └── secrets/
│   ├── homeserver-vm/                 # Homeserver services in a VM
│   │   ├── default.nix
│   │   └── secrets/
│   └── installer/                     # Minimal NixOS ISO for fresh installs
│       └── default.nix
├── scripts/
│   ├── ci-plan.sh                     # CI path filtering and job matrix planner
│   ├── closure-diff.sh                # Closure size diff helper for PR comments
│   ├── validate.sh                    # Local/CI validation entry point
│   ├── vm.sh                          # Archived QEMU VM management for hardware-style testing
│   └── reinstall-homeserver.sh        # Real homeserver reinstall
├── modules/
│   └── nixos/
│       ├── hardware/                  # Hardware-specific modules (NVIDIA PRIME)
│       ├── microvms/                  # microvm.nix VM definitions (homeserver-vm)
│       ├── profiles/
│       │   ├── base.nix               # Base system settings (Nix, locale)
│       │   ├── desktop.nix            # Desktop environment (Hyprland, PipeWire)
│       │   ├── security.nix           # Security hardening (Firewall, SSH)
│       │   ├── observability/         # LGTM observability stack (Grafana, Loki, Tempo, Mimir)
│       │   ├── observability-client.nix
│       │   ├── backup.nix
│       │   ├── machine-common.nix
│       │   ├── microvm-guest.nix
│       │   ├── sops-base.nix
│       │   ├── user.nix               # User account and home-manager base
│       │   └── vm.nix                 # Shared VM module (hardware, disko, impermanence)
│       └── services/
│           ├── hardened.nix           # Systemd service hardening DSL (sandbox extraction)
│           └── systemd-failure-notify.nix
└── home/
    ├── profiles/                      # User-level profiles (home-manager)
    │   ├── base.nix
    │   ├── desktop.nix
    │   └── workstation.nix            # Workstation-specific packages (TeX, Anki, VS Code)
    ├── theme/
    │   ├── active.nix                 # Active theme pointer
    │   ├── module.nix                 # Home Manager theme module
    │   ├── themes/
    │   └── wallpapers/
    ├── users/
    │   └── user/
    │       ├── home.nix
    │       ├── server.nix
    │       └── wsl.nix                # Portable HM for Windows (WSL)
    └── files/                         # Static dotfiles and scripts
        ├── kitty/
        ├── nvim/
        ├── scripts/
        └── waybar/
```

---

## VM Management

### homeserver-vm (Primary)

The `homeserver-vm` runs as a lightweight microvm on the `main` host via `microvm.nix`. It uses `cloud-hypervisor`, shares the host's Nix store via `virtiofs` for near-instant boots (~7s), and receives secrets through a secure `virtiofs` share.

- **Deploy**: `nh os switch --hostname main .`
- **Control**: `sudo systemctl [start|stop|status] microvm@homeserver-vm.service`
- **Logs**: `sudo journalctl -u microvm@homeserver-vm.service -f`

### QEMU Development VM (Archived / Secondary)

Traditional QEMU/KVM VMs are kept for testing desktop environments, bootloaders, impermanence, or full disk encryption. This is not the day-to-day `homeserver-vm` workflow.

```bash
nix run '.#vm' -- <action> <name>
```

| Action             | Description                                                       |
| ------------------ | ----------------------------------------------------------------- |
| `create <name>`    | Full setup: disk image + ISO boot + nixos-anywhere install + boot |
| `start <name>`     | Launch an existing VM                                             |
| `stop <name>`      | Graceful shutdown (SSH poweroff, falls back to SIGTERM)           |
| `reinstall <name>` | Wipe and reinstall (for disko changes or broken state)            |
| `destroy <name>`   | Delete all VM artifacts (disk, OVMF vars, SSH config)             |
| `ssh <name> [cmd]` | SSH into the VM                                                   |
| `list`             | Show all registered VMs with status                               |
| `init <name>`      | Generate SSH host key and sops secrets for a new VM               |

### Adding a new host

1. Add an entry to `lib/hosts.nix` (role, Home Manager role/profile mapping, and if it's a QEMU VM: SSH port, disk size)
2. Create `hosts/<name>/default.nix` (import `modules/nixos/profiles/vm.nix` for QEMU VMs or appropriate profiles for real hosts)
3. If the host has a checked-in `hardware-configuration.nix`, add a short header documenting its regeneration policy and `Last reviewed: YYYY-MM-DD`.
4. Generate sops secrets: `nix run '.#vm' -- init <name>` (for QEMU VMs) or manual setup for real hosts.

Multiple VMs can run simultaneously — each has its own disk image, OVMF vars, and SSH port (for QEMU).

---

## Hosts

| Host            | Description                                                                        |
| --------------- | ---------------------------------------------------------------------------------- |
| `main`          | Primary workstation, running a full desktop environment with NVIDIA PRIME support. |
| `homeserver`    | Headless server for self-hosted services with an ephemeral root filesystem.        |
| `vm`            | QEMU/KVM dev/test VM with desktop profile. Port 2222.                              |
| `homeserver-vm` | `microvm.nix` guest running homeserver services on `main`, static IP `10.0.100.2`. |
| `installer`     | Minimal ISO configuration used to bootstrap new installations.                     |

### Deployment

| Host            | Command                                  | Notes                                                 |
| --------------- | ---------------------------------------- | ----------------------------------------------------- |
| `main`          | `nh os switch --hostname main .`         | Modern Nix helper (`nh`) for fast rebuilds.           |
| `homeserver`    | `deploy '.#homeserver'`                  | Standard remote deployment via `deploy-rs`.           |
| `vm`            | `deploy '.#vm'`                          | After `nix run '.#vm' -- create vm`.                  |
| `homeserver-vm` | `nh os switch --hostname main .`         | Managed as `microvm@homeserver-vm.service` on `main`. |
| `user@wsl`      | `home-manager switch --flake .#user@wsl` | Portable Home Manager for WSL.                        |

**Cold Installs**: Use `nix run '.#reinstall-homeserver' -- <target-ip>` (which wraps `nixos-anywhere`) only for the initial installation on real hardware. Once bootstrapped, transition to the `deploy-rs` workflow for all configuration updates.

---

## Theming

The color system is designed to be **runtime-swappable**. Most GUI applications (Waybar, Kitty, Mako, Hyprland) source colors generated by Nix from a central theme file. This logic is handled by the `home/theme/module.nix` Home Manager module, which provides a `themes.active` option to set the system-wide theme.

A `theme-switch` script is available in the shell to list and apply themes. It uses the `NIX_REPO` environment variable to locate the configuration.

### How to Switch Themes

1.  **List available themes**:
    ```bash
    theme-switch
    ```
2.  **Switch to a new theme**:
    ```bash
    theme-switch <theme-name>
    ```
    This command updates `home/theme/active.nix`, symlinks the new theme's pre-generated configs into place (Kitty, Hyprland, Hyprlock, Waybar, Mako, wallpaper), and reloads running applications — no rebuild required.

### How to Add a New Theme

1.  **Create a new theme file** in `home/theme/themes/`, following the structure of the existing themes (e.g., `nighthawks.nix`). A theme requires a `name`, `colors` set, and a path to a `wallpaper`.
2.  **The new theme will be available** automatically via the `theme-switch` script.

---

## Services (Homeserver)

The `homeserver` is configured to run the following services, accessible via Tailscale:

| Service         | Purpose                                            | Access                                     |
| --------------- | -------------------------------------------------- | ------------------------------------------ |
| **Tailscale**   | Zero-config VPN for secure remote access.          | Connect from any Tailscale client.         |
| **Nginx**       | Reverse proxy with automatic Tailscale TLS certs.  | `https://homeserver.<tailnet-name>.ts.net` |
| **Vaultwarden** | Self-hosted Bitwarden-compatible password manager. | `https://homeserver...` (via Nginx)        |
| **Syncthing**   | Continuous, peer-to-peer file synchronization.     | `http://localhost:8384` (via SSH tunnel)   |

---

## Observability (homeserver rollout)

`homeserver` now hosts the shared LGTM stack. `main` and `vm` ship logs/metrics/traces to it over authenticated Tailscale HTTPS ingest paths.

### Infrastructure Dashboards

The stack includes pre-configured dashboards for fleet overview and deep-dives into the `main` machine:

- **Main Machine**: Real-time monitoring of disk usage, CPU/Memory load, thermal zones, battery health, failed systemd units, and kernel error logs.
- **Fleet Overview**: Aggregated view of CPU and memory usage across all hosts, combined with centralized systemd journal logs.

### LGTM Stack Components

| Component                   | Purpose                          | Homeserver local endpoint            |
| --------------------------- | -------------------------------- | ------------------------------------ |
| **Grafana**                 | Dashboards and datasource UI     | `http://127.0.0.1:3000`              |
| **Loki**                    | Log storage and querying         | `http://127.0.0.1:3100`              |
| **Tempo**                   | Trace storage/query backend      | `http://127.0.0.1:3200`              |
| **Mimir**                   | Metrics storage/query backend    | `http://127.0.0.1:9009`              |
| **Prometheus**              | Scraping + remote write to Mimir | `http://127.0.0.1:9090`              |
| **Grafana Alloy**           | Journald log shipping to Loki    | local systemd service                |
| **OpenTelemetry Collector** | Trace pipeline to Tempo          | receivers on `127.0.0.1:14317/14318` |

Authenticated ingest routes on `https://homeserver.<tailnet-name>.ts.net`:

- `/obs/loki/` → Loki push API
- `/obs/mimir/` → Mimir remote_write API
- `/obs/otlp/` → OpenTelemetry Collector HTTP ingest

Implementation is shared via `modules/nixos/profiles/observability/`, enabled as a full stack on `homeserver` and `homeserver-vm`, and enabled as telemetry sources on `main` and `vm` through `modules/nixos/profiles/observability-client.nix`.

Grafana admin credentials and ingest credentials are managed with `sops` secrets; keep a mirrored copy in Vaultwarden for operator recovery.

---

## Secrets (sops-nix)

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) and [age](https://age-encryption.org) encryption.

### How it works

- `.sops.yaml` defines rules for which age public keys can decrypt which secret files.
- Keys are grouped by name (e.g., `&user`, `&vm_host`, `&homeserver_vm_age`, `&main_host`, `&homeserver_host`).
- Host keys are derived from their respective SSH host public keys using `ssh-to-age`.
- This allows a host to decrypt its own secrets automatically during activation. The host's SSH key is persisted via `impermanence` to ensure the age key remains stable across reboots.
- The user's personal age key (`user`) can decrypt all secrets.
- The QEMU `vm` has encrypted SSH host keys in `hosts/vm/secrets/`, injected during `create`/`reinstall` so sops works from first boot.
- `homeserver-vm` uses a dedicated age key whose private half is stored in `hosts/main/secrets/secrets.yaml`; `main` decrypts it and exposes it to the guest through a `virtiofs` share at `/run/age-keys/`.

### Setup

1. **Generate your personal age key** (once):

   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

   Add the public key to `.sops.yaml` under the `&user` anchor.

2. **Add a host's age key** before granting it secret access:
   For SSH-host-derived identities, get the host's SSH public key, convert it to an age key, and add it to `.sops.yaml`. The real `homeserver` uses a pre-generated encrypted SSH host key so this can be done before first boot.

   ```bash
   # On the target host, or from a pre-generated host public key
   cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age

   # On your dev machine, add the resulting age key to .sops.yaml
   # under a new anchor (e.g., &homeserver_host) and update the
   # creation_rules to give it access to its secrets file.
   ```

3. **Edit secrets:**
   ```bash
   # Edits a file, decrypting it temporarily
   sops hosts/homeserver/secrets/secrets.yaml
   ```

**Host Key Rotation**: Rotating a host's SSH key or changing its identity requires a corresponding update to `.sops.yaml` (new age key) followed by `sops updatekeys <path/to/secrets.yaml>` to re-encrypt the file for the new key. Failing to do this before deployment will result in a boot-time decryption failure.

---

## Tooling

The flake provides several `devShells` and `apps` for development and maintenance.

| Type       | Name                   | Purpose                                                                                 |
| ---------- | ---------------------- | --------------------------------------------------------------------------------------- |
| `devShell` | `default`              | Main dev shell with `deploy-rs`, `nixos-anywhere`, `sops`, `qemu`, `OVMF`, `nixd`, etc. |
| `devShell` | `security`             | Includes common security tools: `nmap`, `gobuster`, `sqlmap`, `hydra`, `john`, etc.     |
| `app`      | `vm`                   | Archived QEMU VM management: `nix run '.#vm' -- <action> <name>`                        |
| `app`      | `reinstall-homeserver` | Runs `nixos-anywhere` for fresh homeserver install on real hardware.                    |
| `package`  | `installer-iso`        | Minimal NixOS ISO: `nix build '.#installer-iso'`                                        |
| `template` | `python`               | Python dev shell with `uv`, `ruff`, `basedpyright`: `nix flake init -t ~/nix#python`    |

---

## Neovim

A performance-focused configuration built around the Neovim 0.11+ native LSP API and `lazy.nvim`. It prioritizes speed, minimal wrappers, and a keyboard-driven workflow.

| Category       | Powered By       | Description                                                            |
| :------------- | :--------------- | :--------------------------------------------------------------------- |
| **Completion** | `blink.cmp`      | Fast completion engine with built-in Copilot integration.              |
| **Filesystem** | `oil.nvim`       | Edit the filesystem as a text buffer to rename, move, or delete files. |
| **Navigation** | `leap.nvim`      | 2-character jumps to any visible text on screen.                       |
| **LSP**        | Native 0.11      | Minimal setup for `nixd`, `clangd`, `basedpyright`, and `ltex`.        |
| **UI**         | `snacks.nvim`    | Notifications, bigfile support, and a startup dashboard.               |
| **Search**     | `telescope.nvim` | Fuzzy finding for files, live grep, and LSP symbols.                   |

### Highlights

- **Filesystem Editing**: Press `-` to open `oil.nvim`. Batch-rename or move files across folders by editing lines in the buffer and saving.
- **Modern Completion**: `blink.cmp` provides a fast completion menu that includes GitHub Copilot suggestions alongside LSP results.
- **Integrated Tooling**: Full support for debugging (`nvim-dap`), testing (`neotest`), and formatting (`conform`).
- **LaTeX Support**: `vimtex` integration with continuous compilation, SyncTeX support, and an optional grammar checker (`ltex`).
- **Theme Integration**: Colors automatically update to match the system-wide runtime theme.

Detailed keymaps are documented in the [**Neovim Cheat Sheet**](home/files/nvim/CHEATSHEET.md).

---

## Code Quality

### Formatting

Formatting is unified behind `nix fmt` via `treefmt-nix`:

```bash
# Format Nix + shell scripts + Markdown
nix fmt

# Check formatting without modifying files
nix fmt -- --fail-on-change
```

### Git hooks

Pre-commit hooks are configured in [`pre-commit-hooks.nix`](./pre-commit-hooks.nix), and `nix develop` also installs a flake-managed `commit-msg` hook that removes `Co-authored-by:` trailers.

```bash
# Run the full hook set manually
pre-commit run --all-files
```

Included quick checks:

- `treefmt` (Unified formatting for Nix, shell, Markdown)
- `shellcheck` (shell script linting)
- `statix` (Nix lint)
- `deadnix` (dead code)
- `no-plaintext-secrets` (high-signal plaintext secret detector)

If the secret detector flags an intentional value, add a narrow path or glob to `.plaintext-secrets-allowlist` and justify it in the commit/PR.

---

## Validation

```bash
# Fast evaluation only: flake outputs and lightweight checks evaluate
bash scripts/validate.sh flake-eval

# Lightweight blocking checks used by CI
bash scripts/validate.sh light

# Build all host system closures used by CI
bash scripts/validate.sh hosts

# Build smoke tests individually
bash scripts/validate.sh smoke-vm
bash scripts/validate.sh smoke-homeserver

# Build all profile-specific NixOS tests
bash scripts/validate.sh profile-tests

# Build the full heavy KVM-backed suite
bash scripts/validate.sh heavy

# View CVE scanning reports for each host
bash scripts/validate.sh cve-reports
```

`nix flake check` in this repo is intentionally evaluation-oriented. The booted NixOS tests and CVE reports live under `legacyPackages` so they can stay path-gated in CI and opt-in locally.

---

## Tailscale ACLs

Tailscale security rules are managed declaratively within the flake. The `lib/acl.nix` generator processes the `lib/hosts.nix` registry to produce a `acl.hujson` compatible structure.

- **Current Policy Scope**: The ACL model is intentionally minimal. It consumes only `tailscale.tag` from the registry and emits shared fleet-wide rules.
- **Registry Richness**: Other host metadata such as `tailnetFQDN`, `role`, `ip`, and `backup.class` remains available to the rest of the flake, but does not affect ACL generation yet.
- **Generator**: `lib/acl.nix` maps tags to owners and defines the current base access rules (workstations can reach servers; `autogroup:admin` can reach everything).
- **Validation**: Unit tests in `tests/lib/acl.nix` verify both the generated rules and the intentionally minimal output shape.
- **Output**: The generated ACL JSON can be inspected via:
  ```bash
  nix build '.#packages.x86_64-linux.tailscale-acl' --print-out-paths | xargs cat
  ```

---

## Continuous Integration

The repository uses GitHub Actions (`.github/workflows/nix.yml` and `flake-update.yml`) for automated validation and maintenance. The CI pipeline is designed for both correctness and performance, using path-filtering to skip expensive tests when possible.

| Job                  | Description                                                                                                                                   |
| :------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------- |
| **Flake Evaluation** | Runs `bash scripts/validate.sh flake-eval`, which keeps `nix flake check --no-build` as a fast evaluation gate for flake outputs and configs. |
| **Light Checks**     | Runs `bash scripts/validate.sh light` for deploy checks, invariants, SOPS bootstrap validation, and lightweight library tests.                |
| **Linting**          | Runs `statix` (Nix), `deadnix` (dead code), `treefmt` (formatting), and `shellcheck` (shell scripts).                                         |
| **Host Builds**      | Matrix-builds each host closure via `bash scripts/validate.sh host <name>`.                                                                   |
| **Smoke Tests**      | Runs `bash scripts/validate.sh smoke-vm` and `smoke-homeserver` in full NixOS environments when relevant paths change.                        |
| **Profile Tests**    | Matrix-builds each profile test via `bash scripts/validate.sh profile-test <name>`.                                                           |
| **Closure Diff**     | Automatically computes and comments the `nvd` diff of package closures on PRs.                                                                |
| **Merge Gate**       | Consolidates all required checks into a single status; required for branch protection and automated flake updates.                            |
| **Flake Update**     | Automated weekly `flake.lock` updates via GitHub Action; auto-merges if the `merge-gate` passes.                                              |

### Path Filtering & Performance

`scripts/ci-plan.sh` generates the host and test matrices for pull requests. The planner is intentionally conservative: dependency/core changes (`flake.nix`, `flake.lock`, `lib/`, CI wiring) run the full expensive suite, while role-specific changes only run the affected host closures and tests.

Examples:

- Desktop Home Manager changes build `main-ci` and `vm`, but skip homeserver closures.
- Server Home Manager changes build `homeserver` and `homeserver-vm`, but skip desktop closures.
- VM host changes run the `vm` closure and desktop VM smoke test.
- `flake.lock` and shared library changes run every host closure, smoke test, profile test, and closure diff.
- Docs-only and WSL-only changes skip expensive host and VM jobs; the always-on eval, lint, and light checks still run.

The workflow uses **magic-nix-cache** (DeterminateSystems) to accelerate builds via GitHub Actions cache. No secrets or external services required — cache is scoped to the repo automatically.

<!-- > **KVM Requirement**: NixOS integration tests require KVM virtualization. While GitHub-hosted `ubuntu-latest` runners provide `/dev/kvm` for public repositories, private or self-hosted runners must have KVM support enabled to prevent silent job timeouts. -->
