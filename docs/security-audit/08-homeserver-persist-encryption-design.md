# Homeserver Persist Encryption Design

## Goal

Plan and implement encryption for `homeserver` persistent service data, starting with `/persist`.

## Scope

- update disk layout and boot flow for encrypted persistent storage
- define recovery and unattended-boot expectations
- document migration from the current unencrypted layout

## Likely Files

- `hosts/homeserver/disko.nix`
- `hosts/homeserver/default.nix`
- install/recovery docs under `docs/`
- any bootstrap/reinstall workflow impacted by LUKS changes

## Tasks

- [x] choose the encryption boundary: `/persist` only
- [x] decide unlock mechanism: passphrase
- [x] design migration path for an existing deployed host
- [x] encode the disk layout change
- [x] document failure and recovery procedures

## Decisions

### Encryption boundary

Encrypt `/persist` only.

- `homeserver` already uses an impermanent root; long-lived service state lives under `/persist`.
- Encrypting `/persist` removes plaintext storage for the production data that matters here without expanding this branch into a full root-disk redesign.
- Root remains disposable ext4 and can still be reprovisioned from the flake.

### Unlock mechanism

Use a local passphrase for the first implementation.

- Do not assume TPM2 support on the target hardware; the checked-in hardware stub does not describe one.
- Do not add an unattended unlock path in this branch. The repo has no reviewed homeserver initrd SSH or TPM enrollment workflow yet.
- Result: power-loss recovery is not unattended. A cold boot requires a local console unlock before Tailscale, SSH, and the persisted services come back.

## Disk layout change

`hosts/homeserver/disko.nix` now places the `persist` partition inside a LUKS container named `crypt-persist`, with ext4 mounted at `/persist` inside that container.

This keeps the existing impermanence model intact:

- `/` stays ephemeral
- `/persist` remains the only long-lived service-data mount
- persisted SSH host keys still come from `/persist`, so `/persist` must stay `neededForBoot`

## Migration

### Fresh hardware bootstrap

For new hardware, use the normal bootstrap flow:

1. review or regenerate `hosts/homeserver/hardware-configuration.nix`
2. set the required sops secrets
3. run `nix run '.#reinstall-homeserver' -- <target-ip>`
4. unlock `crypt-persist` on the local console during the first boot

### Existing plaintext `/persist`

Do not attempt an in-place conversion on the production host in this branch.

Use a controlled reinstall-and-restore flow instead:

1. copy the current `/persist` data to storage outside the host
2. include the local Restic repository in that export if it is still needed, because `services.restic.backups.local.repository = "/persist/restic-repo"` is wiped by the reinstall
3. reinstall with the new disko layout
4. unlock `crypt-persist` locally on first boot
5. restore the persisted application data and verify service startup before resuming normal deploys

This branch should stay draft until that restore procedure has been tested end to end in a controlled environment.

## Failure And Recovery

- Normal reboot after a power event is blocked until someone enters the `crypt-persist` passphrase on the machine's local console.
- Remote recovery through Tailscale or SSH is unavailable until `/persist` is unlocked and the system reaches stage 2.
- Losing the passphrase means the encrypted `/persist` contents are unrecoverable; recovery then becomes reinstall plus restore from an external backup.
- Because the current backup target is also on `/persist`, migration and disaster recovery both require an external copy of the data before the encrypted layout is considered production-ready.

## Acceptance Criteria

- production persistent data is no longer stored on plaintext ext4
- unattended boot and recovery tradeoffs are explicit
- migration steps are documented before the change is considered merge-ready

## Validation

- evaluate the NixOS config and disk layout
- test install/recovery path in a controlled environment before production rollout

## Notes

- This should stay draft until the migration and recovery story is reviewed end to end.
