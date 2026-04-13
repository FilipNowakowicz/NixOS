# VM Host

NixOS VM for testing deployments. Uses impermanence — ephemeral root, selective persistence.
Deployed via deploy-rs: `deploy .#vm`. Hot-reload: `ssh nixvm 'hyprctl reload'`.

## Fresh Install

Required when `disko.nix` changes (disk layout is fixed by impermanence).

```
nix run '.#bootstrap-vm'
```

Handles: clearing stale SSH host keys, decrypting VM keys from sops, running nixos-anywhere, launching the VM.
Manual fallback: see `scripts/reinstall-vm.sh`.

## Gotchas

- **disko changes = fresh install** — partition layout cannot be changed in place.
- **Sops secrets require the host key** — `hosts/vm/secrets/secrets.yaml` is decrypted using the VM's SSH host key, which is pre-injected by the reinstall script and persisted via impermanence.
- **VM SSH host key** is in `.sops.yaml` under `&vm_host` — regenerating it requires re-encrypting secrets.
