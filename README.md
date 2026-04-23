# NixOS & Home Manager Flake

A single, reproducible NixOS & Home Manager flake designed as a scalable, long-term setup.
The repository separates hardware, host identity, system profiles, and user configuration to support multiple machines and VMs.

---

## Overview

- **Reproducible & Declarative**: NixOS defines the entire system state, services, and hardware. Home Manager manages the user environment and dotfiles.
- **Multi-Host**: Built from reusable profiles to support a primary workstation (`main`), a headless `homeserver`, and multiple VMs.
- **Secrets Management**: Handled by [sops-nix](https://github.com/Mic92/sops-nix) with age encryption, with secrets decrypted at boot by the host itself.
- **Impermanent Root**: VMs and the `homeserver` use an ephemeral root filesystem created with [impermanence](https://github.com/nix-community/impermanence). System state is reset on boot, with persistent data explicitly stored on a `/persist` volume.
- **Declarative Disks**: Disk layouts for all hosts are managed declaratively with [disko](https://github.com/nix-community/disko).
- **Runtime Theming**: A runtime-swappable color system allows changing themes without a full NixOS rebuild.

---

## Secure Boot & Encryption for `main`

The `main` host uses a secure, encrypted systemd-boot setup:

- **Bootloader**: [Lanzaboote](https://github.com/nix-community/lanzaboote) manages Secure Boot, signing a unified kernel image.
- **Disk Encryption**: LUKS encrypts the entire disk.
- **TPM Unlocking**: The system's TPM 2.0 is used to automatically unlock the LUKS-encrypted disk on boot.
- **Hardware Pass-through**: IOMMU is enabled (`intel_iommu=on iommu=force`) for potential VM GPU pass-through.
- **Graphics Drivers**: The configuration uses stable by-path device paths for `AQ_DRM_DEVICES` to ensure stable multi-GPU / monitor performance.

---

## Features

- **Runtime Theming**: A runtime-swappable color system allows changing themes without a full NixOS rebuild.
- **USB Device Control**: USBGuard enabled on `main` with an implicit deny policy to block unauthorized devices.
- **Tailscale ACLs as Nix**: Security rules and tag owners are generated declaratively from the host registry, providing a single source of truth for network access control.
- **Systemd Hardening**: A custom DSL (`services.hardened`) applies a high-security sandbox baseline to critical services (Vaultwarden, Nginx, Syncthing).
- **Intrusion Prevention**: Fail2ban integrated into the security profile with automated E2E testing.
- **Idle Policy (desktop)**: Hypridle locks at 10 minutes of inactivity and suspends at 15 minutes.
- **Centralized Keys**: SSH public keys are managed in `lib/pubkeys.nix` for easy access across the flake.
- **Shared SSH Agent**: Home Manager runs a single user `ssh-agent` service; shells use one shared socket, so loaded keys are reused across terminals.

---

## Repository Structure

```
.
├── flake.nix                          # Flake entry point
├── .sops.yaml                         # SOPS configuration for secret management
├── lib/
│   ├── hosts.nix                      # Host registry (single source of truth for all hosts)
│   ├── generators.nix                 # Typed Alloy HCL generators
│   ├── dashboards.nix                 # Typed Grafana dashboard builders
│   ├── invariants.nix                 # Configuration invariant check builders
│   ├── cve-checks.nix                 # CVE scanning check builders
│   ├── pubkeys.nix                    # Centralized SSH public keys
│   ├── syncthing.nix                  # Shared Syncthing device/folder registry
│   ├── acl.nix                        # Declarative Tailscale ACL generator
│   └── network.nix                    # Centralized network identifiers (tailnet FQDN)
├── hosts/
│   ├── main/                          # Primary workstation
│   │   ├── default.nix
│   │   ├── disko.nix
│   │   └── hardware-configuration.nix
│   ├── homeserver/                    # Headless server (Vaultwarden, Syncthing, Tailscale)
│   │   ├── default.nix
│   │   └── disko.nix
│   ├── vm/                            # Dev/test VM (desktop + home-manager)
│   │   ├── default.nix
│   │   └── secrets/
│   ├── homeserver-vm/                 # Homeserver services in a VM
│   │   ├── default.nix
│   │   └── secrets/
│   └── installer/                     # Minimal NixOS ISO for fresh installs
│       └── default.nix
├── scripts/
│   ├── vm.sh                          # Unified VM management (create/start/stop/etc.)
│   └── reinstall-homeserver.sh        # Real homeserver reinstall
├── modules/
│   └── nixos/
│       ├── hardware/                  # Hardware-specific modules (NVIDIA PRIME)
│       ├── microvms/                  # microvm.nix VM definitions (homeserver-vm)
│       ├── profiles/
│       │   ├── base.nix               # Base system settings (Nix, locale)
│       │   ├── desktop.nix            # Desktop environment (Hyprland, PipeWire)
│       │   ├── security.nix           # Security hardening (Firewall, SSH)
│       │   ├── observability.nix      # LGTM observability stack (Grafana, Loki, Tempo, Mimir)
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

### QEMU Development VMs (Secondary)

Traditional QEMU/KVM VMs for testing desktop environments, bootloaders, or full disk encryption. These are managed through a unified command derived from the host registry.

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

1. Add an entry to `lib/hosts.nix` (role, and if it's a QEMU VM: SSH port, disk size)
2. Create `hosts/<name>/default.nix` (import `modules/nixos/profiles/vm.nix` for QEMU VMs or appropriate profiles for real hosts)
3. Generate sops secrets: `nix run '.#vm' -- init <name>` (for QEMU VMs) or manual setup for real hosts.

Multiple VMs can run simultaneously — each has its own disk image, OVMF vars, and SSH port (for QEMU).

---

## Hosts

| Host            | Description                                                                        |
| --------------- | ---------------------------------------------------------------------------------- |
| `main`          | Primary workstation, running a full desktop environment with NVIDIA PRIME support. |
| `homeserver`    | Headless server for self-hosted services with an ephemeral root filesystem.        |
| `vm`            | QEMU/KVM dev/test VM with desktop profile. Port 2222.                              |
| `homeserver-vm` | QEMU/KVM VM running homeserver services for development. Port 2223.                |
| `installer`     | Minimal ISO configuration used to bootstrap new installations.                     |

### Deployment

| Host            | Command                                  | Notes                                           |
| --------------- | ---------------------------------------- | ----------------------------------------------- |
| `main`          | `nh os switch --hostname main .`         | Modern Nix helper (`nh`) for fast rebuilds.     |
| `homeserver`    | `deploy '.#homeserver'`                  | Run from the `nix develop` shell.               |
| `vm`            | `deploy '.#vm'`                          | After `nix run '.#vm' -- create vm`.            |
| `homeserver-vm` | `deploy '.#homeserver-vm'`               | After `nix run '.#vm' -- create homeserver-vm`. |
| `user@wsl`      | `home-manager switch --flake .#user@wsl` | Portable Home Manager for WSL.                  |

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
    This command updates `home/theme/active.nix`, runs `home-manager switch` (via the flake) using `nh` to apply changes, and reloads running applications instantly. This also updates the symlink at `home/theme/wallpapers/current.png`, which is used by Hyprlock and other UI elements.

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

Implementation is shared via `modules/nixos/profiles/observability.nix`, enabled as a full stack on `hosts/homeserver/default.nix`, and enabled as telemetry sources on `hosts/main/default.nix` and `hosts/vm/default.nix`.

Grafana admin credentials and ingest credentials are managed with `sops` secrets; keep a mirrored copy in Vaultwarden for operator recovery.

---

## Secrets (sops-nix)

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) and [age](https://age-encryption.org) encryption.

### How it works

- `.sops.yaml` defines rules for which age public keys can decrypt which secret files.
- Keys are grouped by name (e.g., `&user`, `&vm_host`, `&homeserver_vm_host`, `&main_host`).
- Host keys are derived from their respective SSH host public keys using `ssh-to-age`.
- This allows a host to decrypt its own secrets automatically during activation. The host's SSH key is persisted via `impermanence` to ensure the age key remains stable across reboots.
- The user's personal age key (`user`) can decrypt all secrets.
- Each VM has its own encrypted SSH host keys in `hosts/<name>/secrets/`, injected during `create`/`reinstall` so sops works from first boot.

### Setup

1. **Generate your personal age key** (once):

   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

   Add the public key to `.sops.yaml` under the `&user` anchor.

2. **Add a host's age key** after its first boot:
   On the new host, get its SSH public key, convert it to an age key, and add it to `.sops.yaml`.

   ```bash
   # On the new host (e.g., homeserver)
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

---

## Tooling

The flake provides several `devShells` and `apps` for development and maintenance.

| Type       | Name                   | Purpose                                                                                 |
| ---------- | ---------------------- | --------------------------------------------------------------------------------------- |
| `devShell` | `default`              | Main dev shell with `deploy-rs`, `nixos-anywhere`, `sops`, `qemu`, `OVMF`, `nixd`, etc. |
| `devShell` | `security`             | Includes common security tools: `nmap`, `gobuster`, `sqlmap`, `hydra`, `john`, etc.     |
| `app`      | `vm`                   | Unified VM management: `nix run '.#vm' -- <action> <name>`                              |
| `app`      | `reinstall-homeserver` | Runs `nixos-anywhere` for fresh homeserver install on real hardware.                    |
| `package`  | `installer-iso`        | Minimal NixOS ISO: `nix build '.#installer-iso'`                                        |

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

### Pre-commit hooks

Pre-commit hooks are configured in [`pre-commit-hooks.nix`](./pre-commit-hooks.nix) and auto-installed when entering `nix develop`.

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
# Run the homeserver VM integration smoke test
nix build '.#checks.x86_64-linux.homeserver-vm-smoke'

# Run the standard VM desktop smoke test
nix build '.#checks.x86_64-linux.vm-smoke'

# Run profile-specific E2E tests
nix build '.#checks.x86_64-linux.profile-security'       # fail2ban blocks attacker
nix build '.#checks.x86_64-linux.profile-observability'  # Alloy ships journal logs to Loki
nix build '.#checks.x86_64-linux.profile-hardening'      # systemd sandbox score < 2.0

# Run library unit tests (generators, etc.)
nix build '.#checks.x86_64-linux.lib-generators'

# Run generator golden tests (snapshot testing for Alloy/Grafana)
nix build '.#checks.x86_64-linux.lib-generators-golden'

# Run configuration invariant checks (assertions for every host)
# e.g., "main has no passwordless sudo", "homeserver has firewall enabled"
nix build '.#checks.x86_64-linux.invariants-main'

# View CVE scanning reports for each host (outputs a text file)
nix build '.#checks.x86_64-linux.homeserver' --print-out-paths | xargs cat
nix build '.#checks.x86_64-linux.main' --print-out-paths | xargs cat

# Check for flake inputs, formatting, and unused variables
nix flake check
```

---

## Tailscale ACLs

Tailscale security rules are managed declaratively within the flake. The `lib/acl.nix` generator processes the `lib/hosts.nix` registry to produce a `acl.hujson` compatible structure.

- **Source of Truth**: The `tailscale.tag` attribute in `lib/hosts.nix` defines the tags for each host.
- **Generator**: `lib/acl.nix` maps tags to owners and defines access rules (e.g., workstations can reach all servers).
- **Validation**: Unit tests in `tests/lib/acl.nix` verify that the generator correctly handles different host configurations.
- **Output**: The generated ACL JSON can be inspected via:
  ```bash
  nix build '.#packages.x86_64-linux.tailscale-acl' --print-out-paths | xargs cat
  ```

---

## Continuous Integration

The repository uses GitHub Actions (`.github/workflows/nix.yml` and `flake-update.yml`) for automated validation and maintenance.

| Job                 | Description                                                                                                                           |
| :------------------ | :------------------------------------------------------------------------------------------------------------------------------------ |
| **Flake Check**     | Runs `nix flake check`, evaluates all host configurations, checks for dead code (`deadnix`), and verifies formatting (`treefmt-nix`). |
| **Flake Update**    | Automated weekly `flake.lock` updates via GitHub Action, opening a PR for review.                                                     |
| **Invariant Check** | Evaluates configuration assertions per host to close the intent/reality gap.                                                          |
| **CVE Scanning**    | Runs `vulnix` against every host closure to report open vulnerabilities without blocking CI.                                          |
| **Golden Tests**    | Verifies that generated configuration files (Alloy/Grafana) match committed snapshots.                                                |
| **Smoke Test**      | Executes integration tests (`vm-smoke`, `homeserver-vm-smoke`) booting full NixOS environments.                                       |
| **Profile Tests**   | Runs specialized NixOS tests for Security, Observability, and Hardening profiles.                                                     |
| **Closure Diff**    | Automatically computes and comments the `nvd` diff of package closures on PRs.                                                        |

### Path Filtering & Performance

To optimize CI runtime, the **Smoke Test** only executes when changes are detected in paths that affect the server configuration (`hosts/homeserver*/**`, `modules/**`, `lib/**`).

The workflow uses **Cachix** (`filipnowakowicz`) to persist built artifacts. To enable pushing from CI, ensure `CACHIX_AUTH_TOKEN` is set in your repository secrets.

<!-- > [!IMPORTANT] -->
<!-- > **KVM Requirement**: NixOS integration tests require KVM virtualization. While GitHub-hosted `ubuntu-latest` runners provide `/dev/kvm` for public repositories, private or self-hosted runners must have KVM support enabled to prevent silent job timeouts. -->
