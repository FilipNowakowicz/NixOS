# NixOS & Home Manager Flake

A single, reproducible **NixOS + Home Manager flake** designed as a scalable, long-term setup.
The repository cleanly separates **hardware**, **host identity**, **system profiles**, and **user configuration**, making it suitable for laptops, servers, VMs, and future expansion.

The guiding principles are:
- explicit configuration over implicit defaults
- secure-by-default system design
- minimal host-specific logic
- reproducibility and composability

---

## Overview

This flake assembles complete NixOS systems and user environments from reusable modules.

- **NixOS** handles system state, services, hardware, and security.
- **Home Manager** is integrated as a NixOS module and is used as the primary dotfiles system.
- Each machine is defined declaratively and can be rebuilt from scratch.

---

## Repository Structure

.
├── flake.nix                     # Flake entrypoint (inputs + system assembly)
├── hosts/
│   └── main/
│       ├── default.nix           # Host definition (imports profiles, defines users)
│       └── hardware-configuration.nix
├── modules/
│   └── nixos/
│       ├── profiles/
│       │   ├── base.nix          # Baseline OS defaults
│       │   ├── desktop.nix       # Desktop stack (X11, WM, audio, fonts)
│       │   └── security.nix      # Secure-by-default hardening
│       └── features/             # Optional, fine-grained system features
├── home/
│   ├── profiles/
│   │   ├── base.nix              # Baseline user environment
│   │   └── desktop.nix           # Optional user desktop layer
│   └── users/
│       └── user/
│           └── home.nix           # User entrypoint (imports home profiles)
└── README.md

### Design notes
- **Profiles** are reusable and username-agnostic.
- **Hosts** define identity (hostname, users, hardware, behaviour).
- **Features** are opt-in and composable (e.g. SSH, virtualization).
- **Large configs** (Neovim, zsh, tmux) are intended to live under `home/files/` and be linked via Home Manager.

---

## Supported Hosts

Currently defined:
- `main` — primary laptop/workstation

Adding a new machine typically requires:
1. `hosts/<name>/hardware-configuration.nix`
2. `hosts/<name>/default.nix`

No profile changes are required.

---

## Usage

### Build or switch a NixOS host

sudo nixos-rebuild switch --flake .#main

### Evaluate without installing (sanity check)

nix flake check  
nix eval '.#nixosConfigurations.main.config.system.build.toplevel'

These commands ensure the system evaluates correctly without touching the running system.

---

## Home Manager

Home Manager is integrated directly into NixOS.
User configuration is attached in the host definition and rebuilt together with the system.

Long-term dotfiles are managed declaratively via Home Manager rather than a separate dotfiles repo.

---

## Security Model

- Firewall enabled by default
- SSH disabled by default (opt-in per host/feature)
- Sudo requires password
- Minimal kernel/sysctl hardening enabled
- No secrets committed to the repository

---

## License

Unlicensed / personal infrastructure.
Reuse at your own risk.
