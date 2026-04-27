# Homeserver SOPS Recipient Reduction

## Goal

Reduce `homeserver` secret blast radius by removing `main_host` as a decryption recipient after bootstrap.

## Scope

- narrow `.sops.yaml` recipient rules for `hosts/homeserver/secrets/*`
- re-encrypt affected files
- document bootstrap and rotation assumptions

## Likely Files

- `.sops.yaml`
- `hosts/homeserver/secrets/secrets.yaml`
- `hosts/homeserver/secrets/*.enc` if re-encryption metadata changes
- `docs/security.md`

## Tasks

- [ ] remove `*main_host` from the `homeserver` creation rule
- [ ] identify all affected encrypted files and re-run `sops updatekeys`
- [ ] document how bootstrap decryption works without `main_host`
- [ ] decide whether any temporary bootstrap recipient is needed

## Acceptance Criteria

- `homeserver` secrets are decryptable by operator key and `homeserver_host`, not `main_host`
- all affected encrypted files are re-keyed consistently
- docs explain the operational implications before merge

## Validation

- `sops updatekeys` on affected files
- inspect `.sops.yaml` recipient set
- `nix build '.#checks.x86_64-linux.homeserver-sops-bootstrap'`

## Notes

- This PR is operationally sensitive. Secret rotation details should be reviewed manually before merge.
