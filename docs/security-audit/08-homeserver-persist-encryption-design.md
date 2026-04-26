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

- [ ] choose the encryption boundary: `/persist` only or broader
- [ ] decide unlock mechanism: TPM2, passphrase, or hybrid
- [ ] design migration path for an existing deployed host
- [ ] encode the disk layout change
- [ ] document failure and recovery procedures

## Acceptance Criteria

- production persistent data is no longer stored on plaintext ext4
- unattended boot and recovery tradeoffs are explicit
- migration steps are documented before the change is considered merge-ready

## Validation

- evaluate the NixOS config and disk layout
- test install/recovery path in a controlled environment before production rollout

## Notes

- This should stay draft until the migration and recovery story is reviewed end to end.
