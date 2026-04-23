# Initrd SSH Exposure: Risk Model & Constraints Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add flush-network-before-stage2 systemd unit to hosts/main and document the initrd SSH recovery posture.

**Architecture:** Single host change in hosts/main/default.nix — a oneshot systemd unit in the initrd that tears down all non-loopback interfaces before stage 2 transition, plus a comment block explaining the recovery requirements. GOALS.md updated to close the P1 task.

**Tech Stack:** NixOS, systemd initrd, iproute2 (ip command)

---

### Task 1: Add flush-network-before-stage2 service and documentation comment

**Files:**

- Modify: `hosts/main/default.nix:56-73`

- [ ] **Step 1: Replace the initrd block with the updated version**

In `hosts/main/default.nix`, replace the existing `initrd` block (lines 56-73):

```nix
    initrd = {
      # Systemd in initrd (required for initrd SSH)
      systemd.enable = true;

      # Initrd SSH (fallback LUKS unlock when TPM2 fails)
      network = {
        enable = true;
        ssh = {
          enable = true;
          port = 2222;
          authorizedKeys = import ../../lib/pubkeys.nix;
          hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
        };
      };
      secrets = {
        "/etc/secrets/initrd/ssh_host_ed25519_key" = lib.mkForce "/run/secrets/initrd_ssh_host_ed25519_key";
      };
    };
```

with:

```nix
    initrd = {
      # Systemd in initrd (required for initrd SSH)
      systemd = {
        enable = true;
        # Tear down all non-loopback interfaces before transitioning to stage 2.
        # Ensures port 2222 stops being reachable the moment stage 1 is done,
        # before stage 2's firewall loads. Guards against future misconfiguration
        # (e.g. if WiFi support were added to initrd later).
        services.flush-network-before-stage2 = {
          description = "Tear down initrd network before transitioning to stage 2";
          before = [ "initrd-cleanup.service" ];
          wantedBy = [ "initrd.target" ];
          unitConfig.DefaultDependencies = false;
          serviceConfig = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "flush-initrd-network" ''
              for iface in /sys/class/net/*; do
                iface=$(basename "$iface")
                [ "$iface" = "lo" ] && continue
                ip link set dev "$iface" down 2>/dev/null || true
                ip addr flush dev "$iface" 2>/dev/null || true
              done
            '';
          };
        };
      };

      # Initrd SSH — fallback LUKS unlock when TPM2 fails.
      # Recovery requires a USB Ethernet dongle; WiFi is not available in stage 1.
      # Port 2222 is therefore NOT exposed on WiFi (including public WiFi).
      # flush-network-before-stage2 tears down the interface before stage 2 starts.
      network = {
        enable = true;
        ssh = {
          enable = true;
          port = 2222;
          authorizedKeys = import ../../lib/pubkeys.nix;
          hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
        };
      };
      secrets = {
        "/etc/secrets/initrd/ssh_host_ed25519_key" = lib.mkForce "/run/secrets/initrd_ssh_host_ed25519_key";
      };
    };
```

- [ ] **Step 2: Verify the build evaluates cleanly**

Run: `nix build '.#checks.x86_64-linux.invariants-main' 2>&1 | tail -20`

Expected: build succeeds with no errors. If it fails with "attribute missing" or type errors, check that `pkgs` is in scope (it is — `hosts/main/default.nix` receives `pkgs` as a module argument).

- [ ] **Step 3: Commit**

```bash
git add hosts/main/default.nix
git commit -m "feat(main): flush initrd network before stage 2 transition"
```

---

### Task 2: Update GOALS.md

**Files:**

- Modify: `GOALS.md:82-103`

- [ ] **Step 1: Mark the P1 initrd SSH task complete**

In `GOALS.md`, replace:

```markdown
- [ ] **Review initrd SSH exposure risk model and add constraints if needed.**
  - **Context:** initrd firewall controls differ; port 2222 exposure depends on network posture.
  - **Do this (if threat model requires):** add tighter initrd network restrictions (for example flush-before-stage2/limited exposure) and document expected boot-network assumptions.
    "Result: the initrd SSH exposure is conditional in your current config, not always-on.
```

(and everything through the closing `"` of the audit quote block, ending at line ~103)

with:

```markdown
- [x] **Review initrd SSH exposure risk model and add constraints if needed.**
  - **Findings:** initrd SSH (port 2222) is NOT exposed on WiFi — WiFi drivers/WPA
    supplicant are unavailable in stage 1. Recovery requires a USB Ethernet dongle
    (wired only). Public WiFi exposure risk is not a real concern.
  - **Done:** added `flush-network-before-stage2` systemd unit in initrd
    (`hosts/main/default.nix`) — tears down all non-loopback interfaces before stage 2
    transition (defense-in-depth). Added comment block documenting dongle requirement
    and WiFi limitation.
  - **Follow-up (operational):** acquire a USB-C Ethernet dongle and test initrd SSH
    recovery end-to-end before relying on it in an emergency.
```

- [ ] **Step 2: Commit**

```bash
git add GOALS.md
git commit -m "docs: close P1 initrd SSH exposure task with findings"
```
