# NixOS & Home Manager flake

Single flake driving all NixOS hosts and the `user` Home Manager configuration. Hardware, host personalities, and reusable role
modules live in separate folders to keep intent clear and composable.

## Layout
- `flake.nix` – pins nixpkgs/home-manager and exposes NixOS + Home Manager outputs.
- `hardware/` – per-machine hardware profiles (bootloader, disks, CPU/initrd settings only).
- `hosts/` – thin host modules that compose hardware, role modules, and home-manager for `user`.
- `modules/` – reusable NixOS roles: `base`, `desktop`, `crypto`, `qemu`, `security`.
- `home/` – Home Manager modules for `user` (CLI defaults + optional desktop layer).
- `future/` – parked NixOS modules for virtual machines you may revisit later.

## Usage
```bash
# Switch a NixOS host
sudo nixos-rebuild switch --flake .#<hostname>

# Apply Home Manager on a non-NixOS system (Arch, etc.)
home-manager switch --flake .#user-arch
```

### Host names
- `main`

The active host imports its matching file from `hardware/`, the appropriate role modules from `modules/`, and enables home-manager
for `user` with `home/default.nix` plus `home/desktop.nix` on GUI machines.

## Notes
- `system` is set to `x86_64-linux` for all builds.
- Substituters for `cache.nixos.org` and `nix-community` are configured in the flake.
- Unfree packages are enabled; adjust `config.allowUnfree` in `flake.nix` if you prefer otherwise.
