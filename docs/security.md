# Security Model

This document captures the current security-relevant design. It is descriptive,
not a substitute for reviewing the NixOS modules before deploying sensitive
changes.

## Secrets

Secrets are managed by `sops-nix` with age recipients configured in `.sops.yaml`.
Some recipient groups belong to inactive targets; keep them current enough for
evaluation and future reactivation, but do not treat them as live service access.

Current recipient groups:

| Group                | Purpose                                                                               |
| :------------------- | :------------------------------------------------------------------------------------ |
| `&user`              | Personal operator key; can decrypt all repo secrets.                                  |
| `&vm_host`           | QEMU `vm` SSH-host-derived age identity.                                              |
| `&homeserver_vm_age` | Dedicated age recipient for `homeserver-vm`; private key is stored in `main` secrets. |
| `&main_host`         | `main` SSH-host-derived age identity.                                                 |
| `&homeserver_host`   | Pre-generated homeserver SSH-host-derived age identity.                               |

Host behavior:

- `main`, `vm`, and `homeserver` use SSH-host-derived age identities through `sops.age.sshKeyPaths`.
- `homeserver-vm` disables SSH-host-derived sops identities and reads a dedicated age key from `/run/age-keys/homeserver-vm.txt`.
- `homeserver` bootstrap decrypts the checked-in host key material with `&user` on the operator machine, injects it during reinstall, and then relies on `&homeserver_host` from first boot onward.
- `boot.initrd.secrets` must point only at sops-managed `/run/secrets/*` paths; this is enforced by an invariant check.
- Intentional plaintext exceptions must be narrow entries in `.plaintext-secrets-allowlist`.

## Host Key Rotation

Rotating a host identity requires both the host material and the sops recipient
set to change together.

For SSH-host-derived identities:

1. Generate or capture the new SSH host public key.
2. Convert it with `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`.
3. Update the relevant recipient in `.sops.yaml`.
4. Run `sops updatekeys <secret-file>` for every affected secret file.
5. Deploy only after the target can access the new private key at boot.

For `homeserver-vm`, rotate the dedicated age key, store the private key in
`hosts/main/secrets/secrets.yaml`, update `&homeserver_vm_age`, and re-encrypt
`hosts/homeserver-vm/secrets/secrets.yaml`.

For `homeserver`, no temporary bootstrap recipient is needed. The operator
already decrypts `hosts/homeserver/secrets/ssh_host_ed25519_key{,.pub}.enc`
with `&user` during `reinstall-homeserver`, injects that SSH host key onto the
target, and `sops-nix` derives `&homeserver_host` from `/etc/ssh/ssh_host_ed25519_key`
on first boot. Rotate that host identity by regenerating the encrypted key pair,
updating `&homeserver_host`, and re-encrypting every file under
`hosts/homeserver/secrets/` in the same change.

## Initrd SSH Recovery

`main` exposes initrd SSH on port `2222` only during stage 1 as a fallback for
TPM/LUKS unlock failures.

Constraints:

- Recovery requires wired Ethernet; WiFi is not available in stage 1.
- Authorized keys come from `lib/recovery-pubkeys.nix`.
- Day-to-day SSH access remains on the standard `lib/pubkeys.nix` path.
- The initrd SSH host key is stored as a sops secret.
- `flush-network-before-stage2` tears down non-loopback interfaces before stage 2.

Recovery key management:

- Keep the recovery private key offline; it is not part of normal SSH access.
- Rotate recovery access by updating `lib/recovery-pubkeys.nix`, removing the old
  public key, and redeploying `main` before relying on the new key.

Recovery flow:

```bash
ssh -i /path/to/id_ed25519_recovery -p 2222 root@<host-ip>
```

Then enter the LUKS passphrase when prompted.

## Homeserver Persist Encryption

Inactive target: `homeserver` encrypts `/persist` with LUKS under the mapper
name `crypt-persist` when explicitly provisioned.

Constraints:

- The encryption boundary is `/persist` only. `/` stays ephemeral and reproducible from the flake.
- This host does not yet have TPM2 auto-unlock or initrd SSH recovery configured.
- Cold boots therefore require local console access to enter the `crypt-persist` passphrase before stage 2.
- Tailscale, SSH, and the persisted services remain unavailable until `/persist` is unlocked.

Migration posture:

- Fresh installs use the encrypted layout directly.
- Existing plaintext `/persist` systems should migrate by external backup, reinstall, and restore.
- The current local Restic repository also lives on `/persist`, so it must be copied off-host before using reinstall as the migration path.

## Network Exposure

Tailscale is the primary remote-access layer.

- Inactive `homeserver` keeps SSH enabled for deploy and break-glass access, but only on `tailscale0`, when deployed.
- Inactive `homeserver` exposes SSH and HTTPS only on `tailscale0`; it does not globally open TCP `22` or `443`.
- Inactive `homeserver` exposes HTTPS on the tailnet FQDN from `lib/hosts.nix` when deployed.
- Inactive `homeserver` obtains TLS material through `tailscale-cert.service`; do not enable ACME for that virtual host.
- Observability ingest paths are protected with basic auth sourced from sops when the stack is activated.
- `main` enables SSH but does not open the normal firewall path for general LAN access.

Tailscale ACL output is generated by `lib/acl.nix`. Workstation-to-server
access is derived from explicit registry metadata in `lib/hosts.nix`:
`tailscale.acceptFrom` defines the approved inbound TCP ports per source tag,
and `tailnetFQDN` is used when host-specific destinations need a stable tailnet
name. Admin break-glass access remains a separate deliberate rule.

## USBGuard

`main` uses USBGuard with a deny-default posture. The checked-in policy should
only allow devices that are intentionally trusted. Adding a new USB device
should be done by vendor/product ID and reviewed as a security change.

## Systemd Hardening

The `services.hardened` DSL in `modules/nixos/services/hardened.nix` applies a
baseline sandbox to selected services. Service-specific relaxations should be
documented in the host module near the service they affect.

Validation coverage includes:

- invariant checks for high-level host expectations;
- `profile-hardening` NixOS test for sandbox behavior;
- service-specific smoke tests for homeserver paths.

## Backups

Backup policy is driven by `hostMeta.backup.class` from `lib/hosts.nix` and
implemented by `modules/nixos/profiles/backup.nix`.

Current classes:

| Class      | Retention                               |
| :--------- | :-------------------------------------- |
| `critical` | 14 daily, 8 weekly, 6 monthly, 2 yearly |
| `standard` | 7 daily, 4 weekly, 3 monthly            |

Current repositories are local paths. Off-site backup is tracked as deferred
work in `docs/goals.md`.
