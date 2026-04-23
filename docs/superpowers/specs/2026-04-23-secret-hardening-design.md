# Secret Hardening Design

**Date:** 2026-04-23
**Scope:** Two security fixes on `main` host — initrd SSH key rotation and OTel env secret leak.

---

## Task 1: Initrd SSH Host Key Rotation

### Problem

`hosts/main/initrd-ssh-host-key` is a plaintext OpenSSH private key committed to git. It is used by `boot.initrd.secrets` to enable SSH-based LUKS unlock on port 2222 when TPM2 fails. Anyone with git access can perform a MITM during remote unlock.

The key is no longer trusted once it has been in the git history — rotation is required.

### Design

**Key storage:** Generate a new ed25519 key, encrypt it into `hosts/main/secrets/secrets.yaml` via sops under the key `initrd_ssh_host_ed25519_key`. The existing `.sops.yaml` rule for `hosts/main/secrets/.*` (user + main_host age keys) applies without changes.

**sops-nix declaration** in `hosts/main/default.nix`:

```nix
sops.secrets.initrd_ssh_host_ed25519_key = {};
```

Decrypts to `/run/secrets/initrd_ssh_host_ed25519_key` at activation time.

**`boot.initrd.secrets` update:**

```nix
boot.initrd.secrets = {
  "/etc/secrets/initrd/ssh_host_ed25519_key" = lib.mkForce "/run/secrets/initrd_ssh_host_ed25519_key";
};
```

References the sops-decrypted path instead of the committed plaintext file.

**Removal:** Delete `hosts/main/initrd-ssh-host-key` and `hosts/main/initrd-ssh-host-key.pub` from the repo in a new commit. No git history rewrite — the old key is burned by rotation.

**Deployment sequence:**

1. Add new key to `secrets.yaml` via sops
2. Update `default.nix` (sops secret + initrd path)
3. `nh os switch --hostname main .` — sops decrypts key, rebuild embeds it in new initrd
4. Delete plaintext files, commit

---

## Task 2: OTel `/tmp` Secret Leak Fix

### Problem

`hosts/main/default.nix:262-264` renders a decrypted secret to `/tmp/otel-env` in a systemd `preStart` hook. `/tmp` uses default umask and is potentially world-readable. The `EnvironmentFiles` directive then sources this file into the `opentelemetry-collector` service.

### Design

**New module option** in `modules/nixos/profiles/observability.nix`:

```nix
ingestAuth.serviceEnvironmentFile = lib.mkOption {
  type = with lib.types; nullOr path;
  default = null;
  description = "Path to an env file containing BASICAUTH_PASSWORD for the OTel collector.";
};
```

The module wires it as `serviceConfig.EnvironmentFiles` on `opentelemetry-collector` when non-null. The existing `shouldUseIngestAuth` guard (based on `passwordFile`) continues to control Alloy and Prometheus config; `serviceEnvironmentFile` is an independent gate for the OTel systemd service only.

**In `hosts/main/default.nix`:**

- Remove `systemd.services."opentelemetry-collector".preStart` and its `EnvironmentFiles` override entirely.
- Add `sops.templates` entry:
  ```nix
  sops.templates."otel-env" = {
    content = "BASICAUTH_PASSWORD=${config.sops.placeholder.observability_ingest_password}";
    owner = "opentelemetry-collector";
    mode = "0400";
  };
  ```
- Wire to module:
  ```nix
  profiles.observability.ingestAuth.serviceEnvironmentFile =
    config.sops.templates."otel-env".path;
  ```

The rendered file lives at `/run/secrets-rendered/otel-env` — tmpfs, mode 0400, owned by the service user, gone on reboot.

**Future:** This pattern (sops.templates → serviceEnvironmentFile) should be used on `homeserver` if it ever gains ingest auth, rather than repeating the preStart approach.

---

## Files Changed

| File                                       | Change                                                                                                     |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| `hosts/main/secrets/secrets.yaml`          | Add `initrd_ssh_host_ed25519_key` secret                                                                   |
| `hosts/main/default.nix`                   | Add sops secret decl, update initrd path, add sops.templates, wire serviceEnvironmentFile, remove preStart |
| `hosts/main/initrd-ssh-host-key`           | Delete                                                                                                     |
| `hosts/main/initrd-ssh-host-key.pub`       | Delete                                                                                                     |
| `modules/nixos/profiles/observability.nix` | Add `ingestAuth.serviceEnvironmentFile` option + EnvironmentFiles wiring                                   |
