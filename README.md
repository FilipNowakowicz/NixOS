# NixOS & Home Manager Flake

A single, reproducible NixOS & Home Manager flake designed as a scalable, long-term setup.
The repository separates hardware, host identity, system profiles, and user configuration to support machines, servers, and VMs.

---

## Overview

- NixOS defines system state, services, hardware, and security.
- Home Manager is integrated as a NixOS module and used as the dotfiles system.
- Each host is built from reusable profiles plus a small host definition.

---

## Repository Structure

```
.
├── flake.lock
├── flake.nix                     # Flake entry point: defines systems, hosts, Home Manager
├── hosts
│   └── main
│       ├── default.nix           # Main host config (imports NixOS profiles/modules)
│       └── hardware-configuration.nix
├── modules
│   └── nixos
│       ├── features
│       └── profiles
│           ├── base.nix           # Core system baseline (nix, users, locale)
│           ├── desktop.nix        # Desktop system layer (X11, WM, audio)
│           └── security.nix       # System hardening (firewall, sudo, sysctl)
├── home
│   ├── profiles
│   │   ├── base.nix               # Base Home Manager layer (CLI tools, defaults)
│   │   └── desktop.nix            # Desktop HM layer (GUI apps, services)
│   ├── users
│   │   └── user
│   │       └── home.nix           # User HM entry point (imports profiles + files)
│   ├── files
│   │   ├── awesome                # Awesome Window Manager
│   │   │   ├── autorun.sh
│   │   │   ├── hash
│   │   │   ├── helpers
│   │   │   ├── rc.lua             
│   │   │   └── theme
│   │   ├── kitty                  # Kitty Terminal
│   │   │   ├── current-theme.conf
│   │   │   └── kitty.conf         
│   │   ├── nvim                   # Neovim
│   │   │   ├── init.lua           
│   │   │   ├── lazy-lock.json
│   │   │   ├── lua
│   │   │   └── spell
│   │   ├── tmux                   # Terminal Multiplexer
│   │   │   └── tmux.conf
│   │   └── zsh                    # Z Shell
│   │       ├── zshenv
│   │       └── zshrc
└── README.md                     

```


---

## Supported Hosts

Currently defined:
- main — primary machine/workstation

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
