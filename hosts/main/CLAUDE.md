# main Host

Primary workstation. Uses LUKS, Btrfs, impermanence, Lanzaboote Secure Boot,
Tailscale, Mullvad, USBGuard, Restic/B2 backups, and a full desktop stack.

Status: **active** — hardware-bound to the owner's laptop/workstation.

## Quick Reference

```bash
nh os switch --hostname main .
systemctl status rollback-root.service --no-pager
systemctl list-timers --all --no-pager | rg 'restic|btrfs|fstrim|nix'
journalctl -b -u rollback-root.service --no-pager
```

## Storage Model

- **Disk layout**: `hosts/main/disko.nix` targets the stable NVMe by-id path and creates an ESP plus LUKS-encrypted Btrfs.
- **Subvolumes**: `@root`, `@home`, `@nix`, and `@persist`.
- **Ephemeral root**: initrd systemd moves the current `@root` to top-level `old_roots/<timestamp>` and snapshots `@root-blank` back to `@root` on every boot.
- **Persistent mounts**: `hosts/main/impermanence.nix` and `modules/nixos/profiles/impermanence-base.nix` bind state from `/persist`.
- **Boot-critical mounts**: `/nix` and `/persist` are `neededForBoot`; do not remove this without proving stage 1 still reaches stage 2.

## Persistent State

Current explicit persistence includes:

- `/etc/machine-id`
- `/etc/ssh/ssh_host_ed25519_key*`
- `/etc/NetworkManager/system-connections`
- `/etc/mullvad-vpn`
- `/var/cache/mullvad-vpn`
- `/var/lib/tailscale`
- `/var/lib/bluetooth`
- `/var/lib/fprint`
- `/var/lib/sbctl`
- `/var/lib/usbguard`
- `/var/lib/nixos`
- `/var/lib/systemd/coredump`
- `/var/log`

When adding a stateful service, copy existing live state into `/persist` before
adding the path to impermanence. Otherwise the bind mount starts empty and the
service may lose state at the next rollback boot.

## Backups

`services.restic.backups.local` backs up selected home directories and
persistent service identity to `b2:filipnowakowicz-backup:/main`.

Important covered state:

- `~/.ssh`, `~/.gnupg`, browser/app profiles, Anki, KWallet, repo checkout.
- `~/.codex`, `~/.claude`, `~/.claude.json`.
- Wi-Fi profiles, Mullvad account/device state, Tailscale node identity,
  Bluetooth pairings, fingerprint enrollments, USBGuard state, Secure Boot PKI,
  machine-id, and SSH host identity.

Manual verification:

```bash
sudo systemctl start restic-backups-local.service
sudo systemctl start restic-check-local.service
journalctl -u restic-backups-local.service -n 120 --no-pager
journalctl -u restic-check-local.service -n 120 --no-pager
```

The `main` host has scoped passwordless sudo for these Restic start/status
commands so an interactive agent can run them after the rule is deployed.

## Scoped Agent Maintenance Sudo

Normal `wheel` sudo still requires a password. `hosts/main/default.nix` declares
a narrow `agentMaintenanceCommands` allowlist for `user` with `NOPASSWD`.

Allowed categories:

- start/status for `restic-backups-local` and `restic-check-local`;
- `bootctl status --no-pager` and `bootctl cleanup`;
- `efibootmgr -b XXXX -B` for explicit EFI entry deletion;
- `nix-collect-garbage --delete-older-than *`;
- `nh os switch --hostname main /home/user/nix`.

Do not replace this with broad passwordless sudo. Add new commands only when
they are repeat maintenance operations and can be expressed narrowly.

## Recovery Notes

- TPM2 normally unlocks LUKS automatically.
- Initrd SSH listens on port `2222` only during stage 1 for recovery unlock.
- Initrd SSH requires wired Ethernet; Wi-Fi is unavailable in stage 1.
- Recovery keys live in `lib/recovery-pubkeys.nix`.
- Initrd networking is flushed before stage 2.

## Gotchas

- **disko changes are destructive** unless you are only changing metadata for a future reinstall.
- **Do not persist broad directories by default**; keep persistence minimal and service-owned.
- **OpenSSH uses only the persisted Ed25519 host key**; do not reintroduce volatile RSA host key generation.
- **Mullvad and Tailscale coexistence is fragile**; routing bypass rules are deliberate and lockdown mode is disabled so tailnet traffic can survive when Mullvad is disconnected.
- **Old roots are not normal backups**; they are local forensic rollback artifacts retained for 30 days.
