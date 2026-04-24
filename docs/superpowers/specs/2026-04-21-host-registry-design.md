# Host Registry Design

**Date:** 2026-04-21  
**Scope:** Replace `lib/vm.nix` with a unified `lib/hosts.nix` covering all deployed hosts. Update `flake.nix` to derive nixosConfigurations and deploy-rs nodes from the registry. Host configs in `hosts/` are unchanged.

---

## Motivation

`lib/vm.nix` is a data-driven registry for VMs. `main` and `homeserver` are manually wired in `flake.nix`. Adding a host today means touching three files. The goal is a single source of truth for all hosts so future additions become "add a row."

---

## Registry Schema (`lib/hosts.nix`)

```nix
{
  main = {
    system = "x86_64-linux";
    role = "workstation";
    # No deploy — local-only via `nh os switch`
  };

  homeserver = {
    system = "x86_64-linux";
    role = "homeserver";
    tailnetFQDN = "homeserver.filip-nowakowicz.ts.net";
    deploy.sshUser = "user";
    backup.class = "critical";
  };

  vm = {
    system = "x86_64-linux";
    role = "vm";
    sshPort = 2222;
    diskSize = "40G";
    deploy.sshUser = "user";
  };

  homeserver-vm = {
    system = "x86_64-linux";
    role = "homeserver-vm";
    sshPort = 2223;
    diskSize = "20G";
    deploy.sshUser = "user";
  };
}
```

### Field semantics

| Field            | Type   | Meaning                                                                     |
| ---------------- | ------ | --------------------------------------------------------------------------- |
| `system`         | string | Nix system string for this host; drives `nixosSystem` and deploy activation |
| `role`           | string | Human label; metadata only now, ready to drive modules later                |
| `deploy.sshUser` | string | Presence triggers a deploy-rs node; absence = local-only (main)             |
| `sshPort`        | int    | VM-only; used to filter hosts for the VM script                             |
| `diskSize`       | string | VM-only; used by nixos-anywhere and qemu-img                                |
| `tailnetFQDN`    | string | Per-host Tailscale FQDN; mirrors `lib/network.nix` today                    |
| `backup.class`   | string | Metadata only now; ready to drive a backup module later                     |

---

## `flake.nix` changes

Three derived views replace all manual wiring:

```nix
let
  hostRegistry = import ./lib/hosts.nix;

  # All hosts → nixosConfigurations
  allNixosConfigs = lib.mapAttrs (name: _: mkNixos name) hostRegistry;

  # Hosts with `deploy` attr → deploy-rs nodes
  deployableHosts = lib.filterAttrs (_: cfg: cfg ? deploy) hostRegistry;
  allDeployNodes = lib.mapAttrs (name: cfg: {
    hostname = name;
    sshUser = cfg.deploy.sshUser;
    magicRollback = false;
    autoRollback = false;
    profiles.system = {
      user = "root";
      path = deploy-rs.lib.${cfg.system}.activate.nixos self.nixosConfigurations.${name};
    };
  }) deployableHosts;

  # Hosts with sshPort+diskSize → VM script env var
  vmRegistry = lib.filterAttrs (_: cfg: cfg ? sshPort && cfg ? diskSize) hostRegistry;
in
{
  nixosConfigurations = allNixosConfigs;
  deploy.nodes = allDeployNodes;
  # vmApp passes vmRegistry as VM_REGISTRY JSON (unchanged interface)
}
```

---

## What changes

- `lib/vm.nix` → deleted
- `lib/hosts.nix` → new, contains all four hosts
- `flake.nix` → derives everything from `lib/hosts.nix`; removes manual `main`/`homeserver` wiring

## What stays the same

- All files under `hosts/` — untouched
- `lib/network.nix` — untouched; host configs still import it directly
- `lib/pubkeys.nix`, `lib/syncthing.nix`, `lib/sandbox.nix` — untouched
- VM script interface — still receives `VM_REGISTRY` JSON, same shape

---

## Extensibility path

When a future need arises (e.g., driving backup config from `backup.class`):

1. Add the field to the relevant host entries in `lib/hosts.nix`
2. Thread `hostMeta = hostRegistry.${name}` through `mkNixos` as `specialArgs`
3. Read `hostMeta` in host configs or a shared module

No registry restructuring needed — it's just adding a field.

---

## Validation

- `nix flake check` — verifies all nixosConfigurations evaluate
- `nix build .#nixosConfigurations.main.config.system.build.toplevel`
- `nix build .#nixosConfigurations.homeserver.config.system.build.toplevel`
- `nix build .#nixosConfigurations.vm.config.system.build.toplevel`
- `nix build .#nixosConfigurations.homeserver-vm.config.system.build.toplevel`
