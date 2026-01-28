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
├── flake.nix
├── hosts
│   └── main
│       ├── default.nix
│       └── hardware-configuration.nix
├── modules
│   └── nixos
│       ├── features
│       └── profiles
│           ├── base.nix
│           ├── desktop.nix
│           └── security.nix
├── home
│   ├── files
│   │   ├── awesome
│   │   │   ├── autorun.sh
│   │   │   ├── hash
│   │   │   │   ├── errors.lua
│   │   │   │   ├── keybindings.lua
│   │   │   │   ├── layouts.lua
│   │   │   │   ├── rules.lua
│   │   │   │   ├── signals.lua
│   │   │   │   ├── startup.lua
│   │   │   │   ├── utils.lua
│   │   │   │   ├── wallpaper.lua
│   │   │   │   └── wibar
│   │   │   ├── helpers
│   │   │   │   └── focus_wrap.lua
│   │   │   ├── rc.lua
│   │   │   ├── README.md
│   │   │   └── theme
│   │   │       ├── 0wall.jpg
│   │   │       ├── layout_icons
│   │   │       ├── rofi
│   │   │       └── theme.lua
│   │   ├── kitty
│   │   │   ├── current-theme.conf
│   │   │   └── kitty.conf
│   │   ├── nvim
│   │   │   ├── init.lua
│   │   │   ├── lazy-lock.json
│   │   │   ├── lua
│   │   │   │   └── config
│   │   │   └── spell
│   │   │       ├── en.utf-8.add
│   │   │       └── en.utf-8.add.spl
│   │   ├── tmux
│   │   │   └── tmux.conf
│   │   └── zsh
│   │       ├── zshenv
│   │       └── zshrc
│   ├── profiles
│   │   ├── base.nix
│   │   └── desktop.nix
│   └── users
│       └── user
│           └── home.nix
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

---

## Home Manager

Home Manager is integrated into NixOS and rebuilt alongside the system.
User configuration is composed from reusable home profiles.


Unlicensed / personal infrastructure.
Reuse at your own risk.
