# NixOS & Home Manager Flake

A single, reproducible NixOS & Home Manager flake designed as a scalable, long-term setup.
The repository separates hardware, host identity, system profiles, and user configuration to support laptops, servers, and VMs.

Principles:
- explicit configuration over implicit defaults
- secure-by-default system design
- minimal host-specific logic
- reproducibility and composability

---

## Overview

- NixOS defines system state, services, hardware, and security.
- Home Manager is integrated as a NixOS module and used as the dotfiles system.
- Each host is built from reusable profiles plus a small host definition.

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
    │           └── home.nix          # User entrypoint (imports home profiles)
    └── README.md

Notes:
- Profiles are reusable and username-agnostic.
- Hosts define identity (hostname, users, hardware, behaviour).
- Features are opt-in and composable (e.g. SSH, virtualization).
- Large configs (Neovim, zsh, tmux) can live under home/files/ and be linked via Home Manager.

---

## Supported Hosts

Currently defined:
- main — primary laptop/workstation

To add a new machine:
1. Create hosts/<name>/hardware-configuration.nix
2. Create hosts/<name>/default.nix

---

## Usage

Build or switch a NixOS host:

    sudo nixos-rebuild switch --flake .#main

Evaluate without installing (sanity check):

    nix flake check
    nix eval '.#nixosConfigurations.main.config.system.build.toplevel'

---

## Home Manager

Home Manager is integrated into NixOS and rebuilt alongside the system.
User configuration is composed from reusable home profiles.

---

## Security Model

- Firewall enabled by default
- SSH disabled by default (opt-in per host/feature)
- Sudo requires password
- Minimal kernel/sysctl hardening enabled
- No secrets committed to the repository

---

## Status

- Phase 1 complete: structure, profiles, and host wiring validated
- Next steps:
  - Incremental migration of user configs (zsh, Neovim, etc.)

---

## License

Unlicensed / personal infrastructure.
Reuse at your own risk.
