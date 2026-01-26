# NixOS & Home Manager flake

Single flake driving all NixOS hosts and the `user` Home Manager configuration. Hardware, host personalities, and reusable role
modules live in separate folders to keep intent clear and composable.

## Layout
- `flake.nix` – pins nixpkgs/home-manager and exposes NixOS + Home Manager outputs.
- `hosts/` – per-machine host modules that include hardware configuration and role composition.
- `modules/nixos/profiles/` – reusable NixOS roles: `base`, `desktop`, `security`.
- `home/profiles/` – Home Manager profiles (CLI defaults + optional desktop layer).
- `home/users/` – per-user Home Manager entrypoints.

## Usage
```bash
# Switch a NixOS host
sudo nixos-rebuild switch --flake .#<hostname>

# Apply Home Manager on a non-NixOS system (Arch, etc.)
home-manager switch --flake .#user-arch
```

### Host names
- `main`

The active host imports its hardware configuration from `hosts/<name>/hardware-configuration.nix`, the appropriate role modules from
`modules/nixos/profiles/`, and enables home-manager for `user` via `home/users/user/home.nix`.

## Notes
- `system` is set to `x86_64-linux` for all builds.
- Substituters for `cache.nixos.org` and `nix-community` are configured in the flake.
- Unfree packages are enabled; adjust `config.allowUnfree` in `flake.nix` if you prefer otherwise.
