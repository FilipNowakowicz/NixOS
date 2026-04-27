# Initrd Recovery Key Separation

## Goal

Separate day-to-day SSH credentials from initrd recovery credentials on `main`.

## Scope

- create a dedicated recovery key list
- switch initrd SSH authorized keys to recovery-only keys
- document rotation and recovery expectations

## Likely Files

- `lib/recovery-pubkeys.nix`
- `hosts/main/default.nix`
- `docs/security.md`
- `README.md` if it references recovery flow

## Tasks

- [ ] create `lib/recovery-pubkeys.nix`
- [ ] update `boot.initrd.network.ssh.authorizedKeys`
- [ ] verify normal user keys remain in the standard SSH auth path
- [ ] document how recovery keys are managed and rotated

## Acceptance Criteria

- initrd SSH no longer imports the general-purpose `lib/pubkeys.nix`
- recovery access still works through the dedicated key set
- docs make the trust-tier separation explicit

## Validation

- `nix build '.#checks.x86_64-linux.invariants-main'`
- evaluate `.#nixosConfigurations.main.config.boot.initrd.network.ssh.authorizedKeys`

## Notes

- Keep this change narrow; do not rotate existing keys in the same PR unless required.
