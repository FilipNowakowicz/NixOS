# homeserver-vm → microvm.nix Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace QEMU-based homeserver-vm orchestration with microvm.nix, running the VM as a systemd service on main with sub-30s boot and declarative lifecycle management.

**Architecture:** homeserver-vm stays as a first-class `nixosConfigurations` entry. A new `modules/nixos/profiles/microvm-guest.nix` profile replaces `vm.nix` (no disko, tmpfs root, virtiofs-based sops key injection). `hosts/main/default.nix` imports the microvm host module and a new `modules/nixos/microvms/homeserver-vm.nix` that declares the VM instance, bridge networking, and age-key setup service.

**Tech Stack:** microvm.nix (cloud-hypervisor backend), virtiofs, systemd-networkd (bridge), sops-nix, impermanence

---

## File Map

| Action    | Path                                       | Responsibility                                                                                 |
| --------- | ------------------------------------------ | ---------------------------------------------------------------------------------------------- |
| Add input | `flake.nix`                                | microvm.nix flake input; `self` in specialArgs                                                 |
| Create    | `modules/nixos/profiles/microvm-guest.nix` | Generic microvm guest: tmpfs root, impermanence base, networking stub, sops key path           |
| Create    | `modules/nixos/microvms/homeserver-vm.nix` | Host-side: vm reference, bridge + NAT, age-key setup service, sops secret                      |
| Modify    | `hosts/homeserver-vm/default.nix`          | Swap vm.nix → microvm-guest.nix; add microvm hardware config, static networking, sops keyFiles |
| Modify    | `hosts/main/default.nix`                   | Import microvm host module + homeserver-vm instance module                                     |
| Modify    | `lib/hosts.nix`                            | Remove sshPort/diskSize/deploy from homeserver-vm; add ip                                      |
| Modify    | `.sops.yaml`                               | Replace homeserver_vm_host age key with dedicated vm age key                                   |
| Modify    | `hosts/main/secrets/secrets.yaml`          | Add homeserver_vm_age_key secret                                                               |
| Modify    | `hosts/homeserver-vm/secrets/secrets.yaml` | Re-encrypt with new age key                                                                    |
| Modify    | `scripts/vm.sh`                            | Add deprecation header                                                                         |
| Modify    | `CLAUDE.md`                                | Update VM Management section                                                                   |
| Modify    | `hosts/homeserver-vm/CLAUDE.md`            | Update workflow docs                                                                           |

---

## Task 1: Add microvm.nix flake input

**Files:**

- Modify: `flake.nix`

- [ ] **Step 1: Add the microvm input**

In `flake.nix`, add to the `inputs` block after `lanzaboote`:

```nix
microvm = {
  url = "github:astro/microvm.nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

- [ ] **Step 2: Expose microvm in the outputs destructuring**

In `flake.nix`, add `microvm` to the `outputs = inputs@{ self, nixpkgs, home-manager, ..., microvm, ... }:` line. Also add `self` if not already present — it needs to be explicitly named for the microvm host module:

```nix
outputs =
  inputs@{
    self,
    nixpkgs,
    home-manager,
    deploy-rs,
    nixos-anywhere,
    disko,
    sops-nix,
    lanzaboote,
    microvm,
    pre-commit-hooks,
    treefmt-nix,
    ...
  }:
```

- [ ] **Step 3: Pass `self` as a specialArg in mkNixos**

`microvm.vms.homeserver-vm.flake = self` (used in Task 4) needs `self` available inside NixOS modules. Update `mkNixos`:

```nix
mkNixos =
  host:
  nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = { inherit inputs self; };
    modules = [
      ./hosts/${host}/default.nix
      home-manager.nixosModules.home-manager
      sops-nix.nixosModules.sops
      lanzaboote.nixosModules.lanzaboote
      disko.nixosModules.disko
      {
        imports = [ ./modules/nixos ];
      }
    ];
  };
```

- [ ] **Step 4: Verify the flake evaluates**

```bash
nix flake show 2>&1 | head -30
```

Expected: flake outputs are listed without errors. The `microvm` input should appear under `inputs`.

- [ ] **Step 5: Commit**

```bash
git add flake.nix flake.lock
git commit -m "feat: add microvm.nix flake input"
```

---

## Task 2: Create microvm-guest.nix profile

**Files:**

- Create: `modules/nixos/profiles/microvm-guest.nix`

This profile is the generic microvm guest base. It replaces what `vm.nix` provided (QEMU hardware, disko, impermanence base) without any QEMU-specific pieces.

- [ ] **Step 1: Create the file**

```nix
# modules/nixos/profiles/microvm-guest.nix
{ inputs, lib, ... }:
{
  imports = [
    inputs.microvm.nixosModules.microvm
    inputs.impermanence.nixosModules.impermanence
  ];

  # ── Boot ──────────────────────────────────────────────────────────────────
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_net"
  ];

  # ── Root filesystem (tmpfs — wiped on each boot) ───────────────────────────
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [
      "size=2G"
      "mode=0755"
    ];
  };

  # /persist is mounted by microvm.volumes; mark it needed for boot so
  # impermanence can bind-mount from it during early activation.
  fileSystems."/persist".neededForBoot = true;

  # ── Impermanence base (hosts extend with service-specific dirs) ────────────
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
  };

  # ── Sops (key file injected via virtiofs by the host) ─────────────────────
  # Hosts set defaultSopsFile and declare secrets; this disables SSH-key
  # derivation in favour of the virtiofs-shared age key.
  sops = {
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = lib.mkForce [ ];
  };

  # ── Networking base (static; hosts configure addresses) ───────────────────
  networking = {
    useDHCP = false;
    useNetworkd = true;
  };
  networking.networkmanager.enable = lib.mkForce false;

  # ── Sudo (passwordless — acceptable for local VMs) ────────────────────────
  security.sudo.wheelNeedsPassword = false;

  # ── SSH ────────────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  # ── Nix ────────────────────────────────────────────────────────────────────
  nix.settings.trusted-users = [
    "root"
    "user"
  ];
}
```

- [ ] **Step 2: Verify the file parses**

```bash
nix-instantiate --parse modules/nixos/profiles/microvm-guest.nix > /dev/null && echo "OK"
```

Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add modules/nixos/profiles/microvm-guest.nix
git commit -m "feat: add microvm-guest NixOS profile"
```

---

## Task 3: Update homeserver-vm/default.nix

**Files:**

- Modify: `hosts/homeserver-vm/default.nix`

Replace the `vm.nix` import with `microvm-guest.nix`, add microvm hardware config (hypervisor, TAP interface, /persist volume, age-key virtiofs share), configure static networking, and switch sops to use the virtiofs-injected age key.

- [ ] **Step 1: Replace the vm.nix import and update sops**

Change the imports block — replace `../../modules/nixos/profiles/vm.nix` with `../../modules/nixos/profiles/microvm-guest.nix`:

```nix
imports = [
  ../../modules/nixos/profiles/base.nix
  ../../modules/nixos/profiles/observability.nix
  ../../modules/nixos/profiles/security.nix
  ../../modules/nixos/profiles/user.nix
  ../../modules/nixos/profiles/microvm-guest.nix
];
```

- [ ] **Step 2: Update the sops block**

Replace `age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];` with `age.keyFiles`:

```nix
sops = {
  defaultSopsFile = ./secrets/secrets.yaml;
  defaultSopsFormat = "yaml";
  age.keyFiles = [ "/run/age-keys/homeserver-vm.txt" ];
  secrets = {
    user_password.neededForUsers = true;
    restic_password = { };
    grafana_secret_key = {
      owner = "grafana";
    };
  };
};
```

- [ ] **Step 3: Add static networking via systemd-networkd**

Add a `systemd.network` block for the VM's static IP. Add it after the `networking.hostName` line:

```nix
systemd.network.networks."20-eth" = {
  matchConfig.Name = "eth*";
  networkConfig = {
    Address = "10.0.100.2/24";
    Gateway = "10.0.100.1";
    DNS = "1.1.1.1";
  };
};
```

- [ ] **Step 4: Add microvm hardware config**

Add a `microvm` block. This declares the hypervisor, TAP NIC, /persist volume, and virtiofs share for the age key:

```nix
microvm = {
  hypervisor = "cloud-hypervisor";

  interfaces = [
    {
      type = "tap";
      id = "vm-homeserver";
      mac = "02:00:00:00:00:01";
    }
  ];

  volumes = [
    {
      image = "persist.img";
      mountPoint = "/persist";
      size = 10240;
      fsType = "ext4";
      label = "persist";
      autoCreate = true;
    }
  ];

  shares = [
    {
      tag = "age-keys";
      source = "/run/microvms/homeserver-vm/age-keys";
      mountPoint = "/run/age-keys";
      proto = "virtiofs";
    }
  ];
};
```

- [ ] **Step 5: Build homeserver-vm to verify the config evaluates**

```bash
nix build '.#nixosConfigurations.homeserver-vm.config.system.build.toplevel' 2>&1 | tail -20
```

Expected: build succeeds (or fails only on secrets decryption, not on config evaluation errors).

> **Note:** If build fails with "attribute 'microvm' missing", the microvm input isn't wired through yet — that's fixed in Task 1 (which should already be done). If it fails with sops decryption errors, that's expected until Task 6 (secrets rotation).

- [ ] **Step 6: Commit**

```bash
git add hosts/homeserver-vm/default.nix
git commit -m "feat: migrate homeserver-vm to microvm-guest profile"
```

---

## Task 4: Create modules/nixos/microvms/homeserver-vm.nix

**Files:**

- Create: `modules/nixos/microvms/homeserver-vm.nix`
- Also create: `modules/nixos/microvms/` directory

This is the **host-side** module, imported by `main`. It declares the microvm VM reference, the bridge networking (managed by systemd-networkd alongside NetworkManager), NAT masquerading for VM internet access, and a oneshot service that copies the decrypted age key into the virtiofs share source directory before the VM starts.

- [ ] **Step 1: Create the module**

```nix
# modules/nixos/microvms/homeserver-vm.nix
{
  self,
  config,
  lib,
  pkgs,
  ...
}:
{
  # ── microvm VM declaration ─────────────────────────────────────────────────
  microvm.vms.homeserver-vm = {
    flake = self;
    autostart = true;
  };

  # ── Bridge networking (host-only, managed by systemd-networkd) ────────────
  # NetworkManager manages WiFi; systemd-networkd manages the microvm bridge.
  # The two coexist by telling NM to ignore bridge and tap interfaces.
  networking.networkmanager.unmanaged = [
    "microvm-br0"
    "interface-name:vm-*"
  ];

  systemd.network = {
    enable = true;
    netdevs."10-microvm-br0" = {
      netdevConfig = {
        Kind = "bridge";
        Name = "microvm-br0";
      };
    };
    networks = {
      "10-microvm-br0" = {
        matchConfig.Name = "microvm-br0";
        networkConfig = {
          Address = "10.0.100.1/24";
          IPv4Forwarding = "yes";
        };
      };
      "20-vm-homeserver" = {
        matchConfig.Name = "vm-homeserver";
        networkConfig.Bridge = "microvm-br0";
      };
    };
  };

  # ── NAT masquerading (VM internet access through main's WiFi) ─────────────
  # Set externalInterface to main's WiFi adapter name.
  # Verify with: ip link show | grep -E '^[0-9]+: w'
  networking.nat = {
    enable = true;
    internalInterfaces = [ "microvm-br0" ];
    externalInterface = "wlo1";
  };

  # ── Age key virtiofs share setup ───────────────────────────────────────────
  # Copies the sops-decrypted age key into the virtiofs source directory
  # before the VM starts. The VM reads it at /run/age-keys/homeserver-vm.txt.
  systemd.services.prepare-homeserver-vm-age-key = {
    description = "Prepare homeserver-vm age key for virtiofs share";
    wantedBy = [ "microvm@homeserver-vm.service" ];
    before = [ "microvm@homeserver-vm.service" ];
    after = [ "sops-install-secrets.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -m 700 /run/microvms/homeserver-vm/age-keys
      install -m 600 \
        ${config.sops.secrets.homeserver_vm_age_key.path} \
        /run/microvms/homeserver-vm/age-keys/homeserver-vm.txt
    '';
  };

  # ── Sops secret (main holds the VM's age private key) ─────────────────────
  sops.secrets.homeserver_vm_age_key = { };
}
```

> **Note on NAT:** If main's WiFi interface is not `wlo1`, find it with `ip link show | grep -E '^[0-9]+: w'` and update `externalInterface`.

- [ ] **Step 2: Verify the file parses**

```bash
nix-instantiate --parse modules/nixos/microvms/homeserver-vm.nix > /dev/null && echo "OK"
```

Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add modules/nixos/microvms/homeserver-vm.nix
git commit -m "feat: add homeserver-vm microvm host module"
```

---

## Task 5: Update hosts/main/default.nix

**Files:**

- Modify: `hosts/main/default.nix`

Import the microvm host module (enables `microvm.vms.*` options) and the homeserver-vm instance module.

- [ ] **Step 1: Add imports**

Add two entries to the `imports` block at the top of `hosts/main/default.nix`:

```nix
imports = [
  ./disko.nix
  ./hardware-configuration.nix
  ../../modules/nixos/hardware/nvidia-prime.nix
  inputs.microvm.nixosModules.host
  ../../modules/nixos/microvms/homeserver-vm.nix
];
```

- [ ] **Step 2: Build main to verify it evaluates**

```bash
nix build '.#nixosConfigurations.main.config.system.build.toplevel' 2>&1 | tail -20
```

Expected: build succeeds. If it fails with "attribute 'homeserver_vm_age_key' not found in secrets", that's expected — the secret doesn't exist yet (Task 6). Any other error needs investigation.

- [ ] **Step 3: Commit**

```bash
git add hosts/main/default.nix
git commit -m "feat: integrate microvm host module into main"
```

---

## Task 6: Generate VM age key and rotate secrets

**Files:**

- Modify: `.sops.yaml`
- Modify: `hosts/main/secrets/secrets.yaml`
- Modify: `hosts/homeserver-vm/secrets/secrets.yaml`

This task bootstraps the new sops key chain: a dedicated age key pair for homeserver-vm, stored as a sops secret on main, and used to re-encrypt the VM's secrets.

- [ ] **Step 1: Generate the age key pair**

```bash
age-keygen 2>&1
```

This prints two lines:

```
# created: 2026-04-22T...
# public key: age1xxxx...
AGE-SECRET-KEY-1XXXX...
```

Note the public key (`age1xxxx...`) and the secret key (`AGE-SECRET-KEY-1XXXX...`) — you need both.

- [ ] **Step 2: Update .sops.yaml**

Replace the `&homeserver_vm_host` anchor with a new `&homeserver_vm_age` anchor using the **public key** from Step 1. Update the creation rule for homeserver-vm secrets to use the new key:

```yaml
keys:
  - &user age1v357mlvnesrq0gcgjystzsqaw4d3avaxz8fnxhlaqpktjzzytvqq796haz

  - &vm_host age18g3r6u8cpw8re990wvpsk8rrvphz5ndthmck4ufk96prua8vuchqkg4h0e

  # Dedicated age key for homeserver-vm (private key stored in main's sops secrets)
  - &homeserver_vm_age age1<REPLACE-WITH-YOUR-PUBKEY>

  - &main_host age1nn9990zfx0azcv9fm0m5gmcw2lhg5e2px0wawgnew0234w3nrdws0v2c0f

  # Homeserver SSH host key converted to age: ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
  # Pre-generate: ssh-keygen -t ed25519 -f /tmp/homeserver_host_key -N "" && ssh-to-age < /tmp/homeserver_host_key.pub
  # Then paste the output here (uncomment before running sops commands):
  # - &homeserver_host age1<fill-in-here>

creation_rules:
  - path_regex: hosts/vm/secrets/.*
    key_groups:
      - age:
          - *user
          - *vm_host
  - path_regex: hosts/homeserver-vm/secrets/.*
    key_groups:
      - age:
          - *user
          - *homeserver_vm_age
  - path_regex: hosts/main/secrets/.*
    key_groups:
      - age:
          - *user
          - *main_host
  - path_regex: hosts/homeserver/secrets/.*
    key_groups:
      - age:
          - *user
          # Uncomment after adding &homeserver_host to keys section above:
          # - *homeserver_host
```

- [ ] **Step 3: Add the VM age key secret to main's secrets**

Open main's secrets file with sops:

```bash
sops hosts/main/secrets/secrets.yaml
```

Add the `homeserver_vm_age_key` entry with the **secret key** from Step 1 (the `AGE-SECRET-KEY-1...` line):

```yaml
homeserver_vm_age_key: "AGE-SECRET-KEY-1XXXX..."
```

Save and close. sops encrypts it automatically.

- [ ] **Step 4: Re-encrypt homeserver-vm secrets with the new key**

The homeserver-vm secrets file is currently encrypted with `*homeserver_vm_host` (the old SSH-derived key). Update its encryption keys:

```bash
sops updatekeys hosts/homeserver-vm/secrets/secrets.yaml
```

When prompted, confirm. sops will re-encrypt the file so it can be decrypted by both `*user` and `*homeserver_vm_age`.

- [ ] **Step 5: Verify the homeserver-vm config now builds cleanly**

```bash
nix build '.#nixosConfigurations.homeserver-vm.config.system.build.toplevel'
```

Expected: build succeeds without sops errors. (Sops secrets are not actually decrypted at build time — this verifies the NixOS config evaluates correctly.)

- [ ] **Step 6: Commit**

```bash
git add .sops.yaml hosts/main/secrets/secrets.yaml hosts/homeserver-vm/secrets/secrets.yaml
git commit -m "feat: rotate homeserver-vm to dedicated age key, store in main sops"
```

---

## Task 7: Update lib/hosts.nix

**Files:**

- Modify: `lib/hosts.nix`

Remove QEMU-specific fields from the homeserver-vm entry (`sshPort`, `diskSize`, `deploy`) and add `ip`.

- [ ] **Step 1: Update the homeserver-vm entry**

Replace:

```nix
homeserver-vm = {
  role = "homeserver-vm";
  sshPort = 2223;
  diskSize = "20G";
  deploy.sshUser = "user";
};
```

With:

```nix
homeserver-vm = {
  role = "homeserver-vm";
  ip = "10.0.100.2";
};
```

- [ ] **Step 2: Verify flake still evaluates**

```bash
nix flake show 2>&1 | grep -E "(homeserver-vm|error)" | head -10
```

Expected: homeserver-vm appears in nixosConfigurations, no errors.

> **Note:** The deploy-rs `allDeployNodes` in `flake.nix` filters on `cfg ? deploy`, so removing `deploy` from homeserver-vm automatically removes it from deploy nodes. No manual change needed in flake.nix.

- [ ] **Step 3: Verify invariants still pass**

```bash
nix build '.#checks.x86_64-linux.invariants-homeserver-vm'
```

Expected: passes.

- [ ] **Step 4: Commit**

```bash
git add lib/hosts.nix
git commit -m "chore: remove QEMU fields from homeserver-vm host registry, add ip"
```

---

## Task 8: Full validation

Run all checks to verify nothing is broken.

- [ ] **Step 1: Check WiFi interface name on main and update if needed**

```bash
ip link show | grep -E '^[0-9]+: w'
```

If the interface name is not `wlo1`, open `modules/nixos/microvms/homeserver-vm.nix` and update `networking.nat.externalInterface` to match.

- [ ] **Step 2: Run the homeserver-vm smoke test**

```bash
nix build '.#checks.x86_64-linux.homeserver-vm-smoke'
```

Expected: all services (vaultwarden, nginx, syncthing, grafana, loki, tempo, mimir, prometheus) start and pass health checks.

- [ ] **Step 3: Run invariant checks**

```bash
nix build '.#checks.x86_64-linux.invariants-homeserver-vm'
nix build '.#checks.x86_64-linux.invariants-main'
```

Expected: both pass.

- [ ] **Step 4: Run flake check**

```bash
nix flake check --no-build 2>&1 | tail -20
```

Expected: no evaluation errors.

- [ ] **Step 5: Deploy to main and start the VM**

```bash
nh os switch --hostname main .
```

Expected: main rebuilds successfully. The `microvm@homeserver-vm.service` systemd service is created.

- [ ] **Step 6: Verify the VM starts**

```bash
sudo systemctl start microvm@homeserver-vm.service
sudo systemctl status microvm@homeserver-vm.service
```

Expected: service is active. Check the journal for boot progress:

```bash
sudo journalctl -u microvm@homeserver-vm.service -f
```

Expected: NixOS boots inside the VM in under 30 seconds.

- [ ] **Step 7: Verify networking**

```bash
ssh user@10.0.100.2
```

Expected: SSH login succeeds.

- [ ] **Step 8: Verify services from main**

```bash
curl -kfsS https://10.0.100.2:8443/ | grep -Eqi 'vaultwarden|bitwarden' && echo "Vaultwarden OK"
curl -fsS http://10.0.100.2:8384/ | grep -qi 'syncthing' && echo "Syncthing OK"
```

Expected: both succeed.

---

## Task 9: Deprecation + docs

**Files:**

- Modify: `scripts/vm.sh`
- Modify: `CLAUDE.md`
- Modify: `hosts/homeserver-vm/CLAUDE.md`

- [ ] **Step 1: Add deprecation header to scripts/vm.sh**

Replace the existing comment block at the top of `scripts/vm.sh` (the `#!/usr/bin/env bash` line and the description block):

```bash
#!/usr/bin/env bash
# ARCHIVED — for impermanence/bootloader/LUKS testing on main hardware only.
# Day-to-day homeserver-vm development uses microvm.nix (see hosts/main/default.nix).
# See: docs/superpowers/specs/2026-04-22-microvm-homeserver-design.md
#
# Unified VM management script.
# All VM infrastructure is derived from the VM_REGISTRY JSON env var
# (set by the Nix wrapper in flake.nix).
#
# Usage: nix run '.#vm' -- <action> <name>
```

- [ ] **Step 2: Update the VM Management section in CLAUDE.md**

Replace the VM Management section in `/home/user/nix/CLAUDE.md` with:

````markdown
## VM Management

### homeserver-vm (microvm — primary workflow)

homeserver-vm runs as a systemd service on `main` via microvm.nix.

```bash
nh os switch --hostname main .   # deploy config changes (starts VM if not running)
sudo systemctl start microvm@homeserver-vm.service   # start manually
sudo systemctl stop microvm@homeserver-vm.service    # stop
sudo journalctl -u microvm@homeserver-vm.service -f  # watch logs
ssh user@10.0.100.2              # SSH into VM (or: ssh homeserver-vm)
```
````

Services are reachable from main at:

- Vaultwarden: `https://10.0.100.2:8443`
- Syncthing: `http://10.0.100.2:8384`

### nix run '.#vm' (QEMU — archived)

`scripts/vm.sh` and `nix run '.#vm'` are archived for testing impermanence,
bootloader, and LUKS on main hardware before real deployment. Not used for
homeserver-vm day-to-day.

```bash
nix run '.#vm' -- create <name>   # Full setup (impermanence testing only)
nix run '.#vm' -- start <name>    # Launch existing VM
nix run '.#vm' -- ssh <name>      # SSH into VM
```

````

- [ ] **Step 3: Update hosts/homeserver-vm/CLAUDE.md**

Replace the file content:

```markdown
# Homeserver VM — Development Target

NixOS VM running homeserver services (Vaultwarden, Syncthing) for testing before
hardware deployment. Runs as a systemd service on `main` via microvm.nix.

## Quick Reference

```bash
nh os switch --hostname main .              # deploy config changes
ssh user@10.0.100.2                         # SSH into VM
sudo systemctl status microvm@homeserver-vm # check VM status
sudo journalctl -u microvm@homeserver-vm -f # watch VM logs
````

## Services

| Service     | URL (from main)         |
| ----------- | ----------------------- |
| Vaultwarden | https://10.0.100.2:8443 |
| Syncthing   | http://10.0.100.2:8384  |
| Grafana     | http://10.0.100.2:3000  |

## Differences from Real Homeserver

- No Tailscale
- Self-signed TLS cert (not Tailscale cert)
- Nginx proxies HTTPS on 8443 → Vaultwarden on 8222
- Networking via static IP on host-only bridge (10.0.100.0/24)

## Architecture

- **Config**: `hosts/homeserver-vm/default.nix` — imports `modules/nixos/profiles/microvm-guest.nix`
- **Host module**: `modules/nixos/microvms/homeserver-vm.nix` — imported by `hosts/main/default.nix`
- **Registry**: `lib/hosts.nix` — ip: 10.0.100.2
- **Secrets**: `hosts/homeserver-vm/secrets/` — age key held in main's sops secrets
- **Persist volume**: `/var/lib/microvms/homeserver-vm/persist.img` on main

## Networking

- Bridge `microvm-br0` on main: 10.0.100.1
- VM static IP: 10.0.100.2
- NAT masquerading via main's WiFi for VM internet access

````

- [ ] **Step 4: Commit**

```bash
git add scripts/vm.sh CLAUDE.md hosts/homeserver-vm/CLAUDE.md
git commit -m "docs: deprecate vm.sh, update CLAUDE.md for microvm workflow"
````
