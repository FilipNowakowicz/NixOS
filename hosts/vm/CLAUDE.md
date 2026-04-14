# VM Host

NixOS VM for testing deployments. Uses impermanence — ephemeral root, selective persistence.

## Quick Reference

```bash
nix run '.#vm' -- create vm       # Full setup: disk + install + boot
nix run '.#vm' -- start vm        # Boot existing VM
nix run '.#vm' -- stop vm         # Graceful shutdown
deploy .#vm                       # Deploy config changes
ssh vm                            # SSH into the VM
```

## Fresh Install (from scratch)

```bash
nix run '.#vm' -- create vm
# Automatically: creates disk, builds ISO, boots it, waits for SSH,
# runs nixos-anywhere with host key injection, boots installed VM.
ssh vm                            # Verify SSH access
```

## Day-to-day Usage

```bash
nix run '.#vm' -- start vm        # Start the VM
deploy .#vm                       # Deploy config changes
ssh vm                            # SSH into the VM
nix run '.#vm' -- stop vm         # Stop the VM
```

## Reinstall (disk layout changed or VM is broken)

```bash
nix run '.#vm' -- reinstall vm
```

## Destroy and recreate

```bash
nix run '.#vm' -- destroy vm
nix run '.#vm' -- create vm
```

## Architecture

- **Config**: `hosts/vm/default.nix` — imports shared `modules/nixos/profiles/vm.nix` (hardware, disko, impermanence base, sudo, SSH)
- **Registry**: `lib/vm.nix` — defines SSH port (2222) and disk size (40G)
- **Secrets**: `hosts/vm/secrets/` — sops-encrypted host keys and secrets
- **Disk images**: `~/.local/share/nixos-vms/vm.qcow2`

## Gotchas

- **disko changes = reinstall** — partition layout cannot be changed in place.
- **Sops secrets require the host key** — `hosts/vm/secrets/secrets.yaml` is decrypted using the VM's SSH host key, which is pre-injected by the create/reinstall flow and persisted via impermanence.
- **VM SSH host key** is in `.sops.yaml` under `&vm_host` — regenerating it requires re-encrypting secrets.
- **OVMF vars** are a writable copy — `destroy` deletes them; `create` regenerates them.
