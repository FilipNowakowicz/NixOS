# Initrd SSH (Remote LUKS Unlock Fallback) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Dropbear SSH in the initrd on `main` so the LUKS passphrase can be entered remotely when TPM2 auto-unlock fails.

**Architecture:** Dropbear runs as a lightweight SSH daemon in the early boot environment. A dedicated ed25519 host key pair is generated once, tracked in the repo, and embedded into the initrd via `boot.initrd.secrets` at build time. Normal TPM2 auto-unlock is unaffected — this is a zero-cost fallback.

**Tech Stack:** NixOS `boot.initrd.network.ssh` (Dropbear), `boot.initrd.secrets`, existing `lib/pubkeys.nix` for authorized keys.

---

### Task 1: Generate the initrd SSH host key

**Files:**

- Create: `hosts/main/initrd-ssh-host-key` (private key, git-tracked)
- Create: `hosts/main/initrd-ssh-host-key.pub` (public key)

> **Security note:** This private key ends up in the Nix store (world-readable on the built system). This is unavoidable for initrd secrets and acceptable — the key is for server identity only, not user auth. An attacker with local access who obtained it could MITM the initrd SSH session but cannot unlock the disk.

- [ ] **Step 1: Generate the key pair**

```bash
cd /home/user/nix
ssh-keygen -t ed25519 -N "" -f hosts/main/initrd-ssh-host-key -C "main-initrd"
```

Expected: two files created — `hosts/main/initrd-ssh-host-key` and `hosts/main/initrd-ssh-host-key.pub`.

- [ ] **Step 2: Verify the key files exist**

```bash
ls -la hosts/main/initrd-ssh-host-key*
```

Expected output (both files present):

```
-rw------- ... hosts/main/initrd-ssh-host-key
-rw-r--r-- ... hosts/main/initrd-ssh-host-key.pub
```

- [ ] **Step 3: Record the host key fingerprint for later known_hosts use**

```bash
ssh-keygen -l -f hosts/main/initrd-ssh-host-key.pub
```

Save the fingerprint output — you'll use it to verify the connection on first SSH and can add it to `~/.ssh/known_hosts`.

---

### Task 2: Configure initrd SSH in hosts/main/default.nix

**Files:**

- Modify: `hosts/main/default.nix`

- [ ] **Step 1: Add the initrd SSH block**

In `hosts/main/default.nix`, add the following section after the `# ── Hardware ────` block (after line ~48, before the `# ── Nix Store` section):

```nix
  # ── Initrd SSH (fallback LUKS unlock when TPM2 fails) ─────────────────────
  boot.initrd.network = {
    enable = true;
    ssh = {
      enable = true;
      port = 2222;
      authorizedKeys = import ../../lib/pubkeys.nix;
      hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
    };
  };

  boot.initrd.secrets = {
    "/etc/secrets/initrd/ssh_host_ed25519_key" = ./initrd-ssh-host-key;
  };
```

- [ ] **Step 2: Verify the diff looks correct**

```bash
git diff hosts/main/default.nix
```

Confirm the block was added and the indentation is consistent with the rest of the file.

---

### Task 3: Build to validate

**Files:** (no changes, just validation)

- [ ] **Step 1: Check flake syntax**

```bash
nix flake check 2>&1 | head -40
```

Expected: no errors (warnings about unfree packages are fine).

- [ ] **Step 2: Build the main host config**

```bash
nh os build --hostname main .
```

Expected: build succeeds. If it fails with a missing attribute error on `boot.initrd.network.ssh`, double-check the option spelling against:

```bash
nix eval nixpkgs#lib.nixosModules --apply 'x: builtins.attrNames x' 2>/dev/null | head -5
# or just check NixOS manual
```

- [ ] **Step 3: Confirm the initrd contains the SSH daemon**

```bash
nix build '.#nixosConfigurations.main.config.system.build.initialRamdisk' -o /tmp/initrd-check
file /tmp/initrd-check
```

Expected: an initrd file (cpio archive or compressed image). This confirms it built correctly.

---

### Task 4: Commit

**Files:**

- `hosts/main/initrd-ssh-host-key`
- `hosts/main/initrd-ssh-host-key.pub`
- `hosts/main/default.nix`

- [ ] **Step 1: Stage and commit**

```bash
git add hosts/main/initrd-ssh-host-key hosts/main/initrd-ssh-host-key.pub hosts/main/default.nix
git commit -m "feat(main): add initrd SSH for remote LUKS unlock fallback"
```

---

### Task 5: Deploy and test

- [ ] **Step 1: Deploy to main**

```bash
nh os switch --hostname main .
```

- [ ] **Step 2: Add the initrd host key to your SSH known_hosts**

```bash
# Use the fingerprint from Task 1, Step 3 to pre-trust the key
# Or add an entry manually to avoid the TOFU prompt on first use:
echo "[main]:2222 $(cat hosts/main/initrd-ssh-host-key.pub)" >> ~/.ssh/known_hosts
```

- [ ] **Step 3: Test by rebooting the machine**

```bash
# From another machine or after you can confirm network is up:
ssh -p 2222 root@<main-ip>
```

Expected: you land at a prompt. Type the LUKS passphrase:

```
Please enter passphrase for disk cryptroot: <your-passphrase>
```

Boot should proceed normally after unlock.

- [ ] **Step 4: Confirm TPM2 normal boot is unaffected**

Reboot a second time without SSHing in. TPM2 should auto-unlock and boot as usual with no delay.

---

## Notes

- **Port 2222** avoids collision with the system OpenSSH port (which defaults to disabled on this machine anyway, per `security.nix`).
- **No firewall rules needed** — the system firewall isn't active during initrd.
- **Network interface:** DHCP on the default interface is assumed. If the machine has multiple NICs and the wrong one is used, add `boot.initrd.network.interfaces.<name>.useDHCP = true` to pin the correct one.
- **Tailscale is not available** during initrd — use the local IP or hostname.
- **Key rotation:** To rotate the initrd host key, regenerate the key pair, recommit, and redeploy.
