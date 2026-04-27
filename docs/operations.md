# Operations

This document is the runbook for day-to-day work in this flake. Keep the
README high-level; put command-heavy procedures here.

## Canonical Sources

- `README.md` - project overview, host inventory, feature map.
- `CLAUDE.md` - agent/operator preferences and validation shortcuts.
- `docs/architecture.md` - structural rules and module boundaries.
- `docs/security.md` - secrets, network exposure, and hardening model.

## Deployment Matrix

| Target          | Command                                  | Notes                                                                       |
| :-------------- | :--------------------------------------- | :-------------------------------------------------------------------------- |
| `main`          | `nh os switch --hostname main .`         | Primary workstation; also owns the `homeserver-vm` microvm service.         |
| `homeserver`    | `deploy '.#homeserver'`                  | Use after the real hardware has been bootstrapped.                          |
| `vm`            | `deploy '.#vm'`                          | Requires a QEMU VM created with `nix run '.#vm' -- create vm`.              |
| `homeserver-vm` | `nh os switch --hostname main .`         | Rebuilds the host-side microvm declaration on `main`; control with systemd. |
| `user@wsl`      | `home-manager switch --flake .#user@wsl` | Portable Home Manager profile for WSL.                                      |

## homeserver-vm

`homeserver-vm` is the primary homeserver development target. It is a
`microvm.nix` guest declared by `modules/nixos/microvms/homeserver-vm.nix` and
run by systemd on `main`.

```bash
nh os switch --hostname main .
sudo systemctl start microvm@homeserver-vm.service
sudo systemctl status microvm@homeserver-vm.service
sudo journalctl -u microvm@homeserver-vm.service -f
ssh user@10.0.100.2
```

Service endpoints from `main`:

| Service     | URL                       |
| :---------- | :------------------------ |
| Vaultwarden | `https://10.0.100.2:8443` |
| Syncthing   | `http://10.0.100.2:8384`  |
| Grafana     | `http://10.0.100.2:3000`  |

Important boundaries:

- Host-side networking is bridge `microvm-br0` at `10.0.100.1`.
- Guest static IP is `10.0.100.2`.
- NAT egress uses `microvms.homeserver-vm.externalInterface` from `hosts/main/default.nix`.
- Guest `/persist` is `/var/lib/microvms/homeserver-vm/persist.img` on `main`.
- Guest sops key material is exposed by `main` through a virtiofs share mounted at `/run/age-keys`.

## QEMU VM

`scripts/vm.sh` and `nix run '.#vm'` are archived for hardware-style testing:
impermanence, bootloader behavior, and LUKS workflows. They are not the
`homeserver-vm` path.

```bash
nix run '.#vm' -- create vm
nix run '.#vm' -- start vm
nix run '.#vm' -- ssh vm
nix run '.#vm' -- stop vm
nix run '.#vm' -- reinstall vm
nix run '.#vm' -- destroy vm
```

QEMU VM metadata comes from `lib/hosts.nix`; entries need `sshPort` and
`diskSize` to appear in the VM registry.

## Homeserver Bootstrap

Cold installs use the flake app that wraps `nixos-anywhere`:

```bash
nix run '.#reinstall-homeserver' -- <target-ip>
```

Before the first hardware install:

1. Replace `hosts/homeserver/hardware-configuration.nix` with reviewed target hardware config.
2. Ensure `hosts/homeserver/secrets/ssh_host_ed25519_key.enc` and `.pub.enc` exist.
3. Ensure `.sops.yaml` includes the matching `&homeserver_host` age key.
4. Set required secrets in `hosts/homeserver/secrets/secrets.yaml`, including `tailscale_auth_key`.
5. Run the reinstall app.
6. Unlock `crypt-persist` on the local console during the first boot.

After bootstrap, prefer `deploy '.#homeserver'` for routine updates.

Current constraint: `homeserver` does not yet have a reviewed unattended unlock path. Cold boots stay blocked until a local operator enters the `/persist` LUKS passphrase.

If migrating an existing plaintext `/persist`, use reinstall-and-restore rather than in-place conversion. Export the application state and the local Restic repository off-host first, because `/persist/restic-repo` is destroyed by the reinstall.

## Validation

Use the narrowest check that covers the files changed.

```bash
bash scripts/validate.sh flake-eval
bash scripts/validate.sh light
bash scripts/validate.sh host main-ci
bash scripts/validate.sh host vm
bash scripts/validate.sh host homeserver
bash scripts/validate.sh host homeserver-vm
bash scripts/validate.sh hosts
bash scripts/validate.sh smoke-vm
bash scripts/validate.sh smoke-homeserver
bash scripts/validate.sh profile-tests
bash scripts/validate.sh heavy
bash scripts/validate.sh cve-reports
```

Rules of thumb:

- Shared flake, library, or global module changes: run `light` and affected host builds; use `hosts` when impact is broad.
- Desktop profile/Home Manager changes: build `main-ci` and `vm`.
- Server profile changes: build `homeserver` and `homeserver-vm`.
- Microvm host-side changes: build `main-ci` and `homeserver-vm`.
- NixOS test changes: run the relevant smoke/profile test if KVM is available.

## Formatting And Hooks

```bash
nix fmt
nix fmt -- --fail-on-change
pre-commit run --all-files
statix check .
deadnix .
```

`nix develop` installs a `commit-msg` hook in the shared git hooks directory
that removes `Co-authored-by:` trailers.
