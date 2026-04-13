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
- **Hot-reload:** `ssh nixvm 'hyprctl reload'`
- **Launch VM:** `nix run '.#launch-vm'`
- **Git** is for version control only, not deployment

### SSH Agent Behavior

- Use Home Manager `services.ssh-agent` as the single SSH agent manager.
- Do not enable `programs.keychain`; stale `~/.keychain` state can cause `ssh-add` failures (`Error connecting to agent: Connection refused`).
- Zsh exports `SSH_AUTH_SOCK` to `${XDG_RUNTIME_DIR:-/run/user/$UID}/ssh-agent`.
- Zsh auto-runs `ssh-add -q ~/.ssh/id_ed25519` only when the shared agent is empty, so passphrase entry happens once per login session and is reused in new terminals.

### Fresh VM install

The VM uses impermanence. A fresh install is required whenever the disk layout (`hosts/vm/disko.nix`) changes.

1.  **Run the bootstrap app**:
    `nix run '.#bootstrap-vm'`
    This script automates the full process of clearing stale keys, decrypting VM keys, running `nixos-anywhere`, and launching the VM.

2.  **Manual alternative**:
    If the bootstrap app fails, follow these steps manually:
    - **Create disk image** (if not already present):
      `qemu-img create -f qcow2 /vmstore/images/nixos-test.qcow2 40G`
    - **Copy OVMF vars** (if not already present):
      `cp /usr/share/OVMF/x64/OVMF_VARS.4m.fd /vmstore/images/nixos-test-vars.fd`
    - **Build the installer ISO**:
      `nix build '.#packages.x86_64-linux.installer-iso'`
    - **Boot the ISO in the VM**:
      `nix run '.#launch-vm-iso' -- result/iso/*.iso`
    - **From the dev shell, run the installation**:
      `nix run '.#reinstall-vm'`
      This script automates the `nixos-anywhere` process:
      - Clears the stale SSH host key from `~/.ssh/known_hosts`.
      - Decrypts the VM's persistent SSH host keys from sops secrets and injects them.
      - Runs `nixos-anywhere` to partition `/dev/vda` (via disko) and install the `vm` configuration from the flake.

3.  **Post-install**: After the installer reboots the VM, launch it normally and deploy any pending changes.
    `nix run '.#launch-vm'`
    `deploy .#vm`

---

## Repository Structure

- `flake.nix` — entry point, defines hosts, home-manager, deploy-rs nodes, VM apps
- `hosts/main/` — real machine config, disko layout, LUKS/LVM
- `hosts/vm/` — VM config, virtio drivers, disko layout, impermanence, sops secrets
- `hosts/installer/` — minimal NixOS ISO config for fresh installs
- `lib/pubkeys.nix` — centralized SSH public keys
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

Secrets are managed with sops-nix and age encryption.

- **Age key (main host):** `~/.config/sops/age/keys.txt`
  Generate with: `age-keygen -o ~/.config/sops/age/keys.txt`
- **VM host key:** converted from the SSH host key using:
  `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`
  The resulting age pubkey goes into `.sops.yaml` under `&vm_host`
- **Main host key:** same process, goes into `.sops.yaml` under `&main_host`
- **Homeserver host key:** same process, add after first deploy under `&homeserver_host`
- **`.sops.yaml`:** repo root, defines key groups per path regex
- **Secrets file:** `hosts/vm/secrets/secrets.yaml` — encrypted, edit with `sops hosts/vm/secrets/secrets.yaml`
- The VM's `/etc/ssh/ssh_host_ed25519_key` is persisted via impermanence so the host key (and thus the age decryption key) survives reboots
- On main, `/etc/ssh/ssh_host_ed25519_key` is stable as it's part of the standard persistent root filesystem.

---

## Goals

### In Progress

- Homeserver deployment — waiting on hardware
  - Replace `hardware-configuration.nix` stub with real hardware config
  - Wire Tailscale auth key: run `sops hosts/homeserver/secrets/secrets.yaml`
    and set `tailscale_auth_key` to a key generated from the Tailscale admin
    console (Settings → Keys → Generate auth key, reusable + ephemeral)
  - Deploy for the first time: `deploy .#homeserver`
  - Add homeserver host age key to `.sops.yaml` after first deploy:
    `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`
    Add the result under `&homeserver_host` in `.sops.yaml`
  - Re-encrypt secrets to include host key:
    `sops updatekeys hosts/homeserver/secrets/secrets.yaml`
  - Vaultwarden first user: temporarily set `SIGNUPS_ALLOWED = true`, deploy,
    create account at `https://homeserver` (via Tailscale), set back to `false`,
    deploy again

### Pending
- Waybar redesign 
- eww floating widgets (deferred)
- Sunshine screen mirror
- Fix inactivity suspension not working
- Impermanence on main — attempted and reverted. Too much friction on a daily driver. Not planned.

---

## Stack

- **NixOS** — declarative Linux distribution
- **Home Manager** — declarative dotfiles and user environment
- **Hyprland** — dynamic tiling Wayland compositor
- **Lanzaboote** — Secure Boot for NixOS (main only)
- **LUKS + LVM** — encrypted disk with logical volumes (main only)
- **sops-nix** — secrets management with age encryption
- **impermanence** — ephemeral root filesystem with selective persistence
- **disko** — declarative disk partitioning
- **nixos-anywhere** — remote NixOS installation
- **deploy-rs** — NixOS deployment tool
- **Tailscale** — mesh VPN for secure remote access

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
- When committing do not add co-authorship
- Never push commits
