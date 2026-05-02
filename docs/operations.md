# Operations

This document is the runbook for day-to-day work in this flake. Keep the
README high-level; put command-heavy procedures here.

## Canonical Sources

- `README.md` - project overview, host inventory, feature map.
- `CLAUDE.md` - agent/operator preferences and validation shortcuts.
- `docs/architecture.md` - structural rules and module boundaries.
- `docs/security.md` - secrets, network exposure, and hardening model.

## Deployment Matrix

| Target          | Status           | Command                                  | Notes                                                          |
| :-------------- | :--------------- | :--------------------------------------- | :------------------------------------------------------------- |
| `main`          | Active           | `nh os switch --hostname main .`         | Primary workstation.                                           |
| `homeserver`    | Inactive         | `deploy '.#homeserver'`                  | Use only after explicit real-hardware bootstrap.               |
| `vm`            | Legacy Supported | `deploy '.#vm'`                          | Requires a QEMU VM created with `nix run '.#vm' -- create vm`. |
| `homeserver-vm` | Inactive         | `nh os switch --hostname main .`         | Only works after enabling the microvm host import in `main`.   |
| `user@wsl`      | Active           | `home-manager switch --flake .#user@wsl` | Portable Home Manager profile for WSL.                         |

## homeserver-vm

`homeserver-vm` is an inactive homeserver development target. It remains a
buildable `nixosConfiguration`, but the host-side microvm integration is
disabled in `hosts/main/default.nix`.

Do not treat the commands below as active workflow commands unless the microvm
import has been deliberately re-enabled on `main`.

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

Reactivation checklist:

1. Confirm `lib/hosts.nix` still marks `homeserver-vm` as intentionally inactive or update the status in the same change.
2. Verify `hosts/main/secrets/secrets.yaml` contains the `homeserver_vm_age_key` secret.
3. Enable the `modules/nixos/microvms/homeserver-vm.nix` import in `hosts/main/default.nix`.
4. Build `main-ci` and `homeserver-vm`, then run `smoke-homeserver` if KVM is available.
5. Rebuild `main`, start `microvm@homeserver-vm.service`, and verify Vaultwarden, Syncthing, and Grafana endpoints.

## QEMU VM

`scripts/vm.sh` and `nix run '.#vm'` are legacy-supported for hardware-style
testing: impermanence, bootloader behavior, and LUKS workflows. They are not
the `homeserver-vm` path.

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

Status: inactive. This path is retained for future real-hardware bootstrap but
is not a current deployment workflow.

Cold installs use the flake app that wraps `nixos-anywhere`.
The script **refuses to proceed without verified host key trust material** —
blind TOFU is not accepted.

### Pre-flight checklist

1. Replace `hosts/homeserver/hardware-configuration.nix` with reviewed target hardware config.
2. Ensure `hosts/homeserver/secrets/ssh_host_ed25519_key.enc` and `.pub.enc` exist.
3. Ensure `.sops.yaml` includes the matching `&homeserver_host` age key.
4. Set required secrets in `hosts/homeserver/secrets/secrets.yaml`, including `tailscale_auth_key`.
5. Update `lib/hosts.nix` status in the same change if this becomes an operated target.
6. Build `homeserver`, then run `smoke-homeserver` if KVM is available.
7. Run the reinstall app.
8. Unlock `crypt-persist` on the local console during the first boot.

### Obtain the installer fingerprint

The NixOS installer generates a fresh ephemeral SSH host key on each boot.
Obtain its fingerprint **before** running the reinstall script, using one of:

- **Serial/video console** — read the fingerprint printed at the login prompt.
- **Manual scan** (run from a trusted network position, verify visually):
  ```bash
  ssh-keyscan -t ed25519 <target-ip> | ssh-keygen -lf /dev/stdin
  ```

### Run the reinstall

```bash
# Verify by fingerprint (recommended — you confirmed the fingerprint out of band)
nix run '.#reinstall-homeserver' -- <target-ip> \
  --expected-fingerprint SHA256:...

# Verify via a pre-populated known_hosts file
nix run '.#reinstall-homeserver' -- <target-ip> \
  --known-hosts /path/to/known_hosts
```

The script scans the target, compares the fingerprint, and aborts on mismatch.
All subsequent SSH connections from `nixos-anywhere` are bound to the verified key
(`StrictHostKeyChecking=yes`).

After bootstrap, prefer `deploy '.#homeserver'` for routine updates.

Current constraint: `homeserver` does not yet have a reviewed unattended unlock path. Cold boots stay blocked until a local operator enters the `/persist` LUKS passphrase.

If migrating an existing plaintext `/persist`, use reinstall-and-restore rather than in-place conversion. Export the application state and the local Restic repository off-host first, because `/persist/restic-repo` is destroyed by the reinstall.

## Validation

Use the narrowest check that covers the files changed.

```bash
bash scripts/validate.sh flake-eval
bash scripts/validate.sh light
bash scripts/validate.sh host main-ci
bash scripts/validate.sh host vm-ci
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
- Desktop profile/Home Manager changes: build `main-ci` and `vm-ci`.
- Server profile changes: build inactive `homeserver` targets to preserve evaluation/build health.
- Microvm host-side changes: build `main-ci` and `homeserver-vm`, but do not assume runtime activation.
- Docs changes: run `bash scripts/validate.sh docs`; CI runs this even for docs-only PRs.
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
