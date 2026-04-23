# Post-Implementation Audit and Documentation Sync

I have recently updated the NixOS configuration with the changes listed below. Not all changes might have the need for documentation. Please perform a multi-layered audit of the current state of the repository:

1.  **Code Analysis:** Review the new and modified `.nix` files for structural consistency, comment accuracy, and idiomatic Nix patterns. Identify any stale comments or logic that contradicts the current implementation.
2.  **Architecture Review:** Evaluate the new file/folder structure. Verify if the placement of new modules or host configurations follows the project's existing organizational logic (e.g., `modules/nixos/` vs `home/profiles/`).
3.  **Documentation Synchronization:**
    - **README.md:** Update the repository overview and feature list to reflect the new additions.
    - **CLAUDE.md:** Update the "Current Focus," deployment commands, or technical notes to ensure they remain a "source of truth" for the primary developer agent.
    - **Consistency Check:** Ensure the tone and formatting in these files match the existing style.
4.  **Verification:** Cross-reference `flake.nix` with the documentation to ensure all new outputs or inputs are accounted for.

Before you change anything first use the 'Plan' mode to plan out the changes. Make sure everything is done cleanly and correctly.

**The main changes are:**

- Generate CVE checks for all hosts, but skip test VMs in CI (CI was running out of space)

## P0 — Critical Security & Architecture (do first)

- [x] **Rotate leaked initrd SSH host key for `main` and migrate to sops-nix-managed initrd secret.**
  - **Context:** `hosts/main/initrd-ssh-host-key` is a committed plaintext private key (`openssh-key-v1` raw format), enabling MITM risk during remote LUKS unlock on initrd SSH (`port 2222`).
  - **Do this:** rotate key on host; store encrypted secret (for example `hosts/main/secrets/initrd_ssh_host_ed25519_key.enc`); inject through `boot.initrd.secrets` (or reinstall path `nixos-anywhere --extra-files`); remove plaintext file; scrub git history (`git filter-repo`) if already exposed.
  - **Hardening follow-up:** extend `no-plaintext-secrets` detection to catch raw/binary private keys and/or blocklist `*_key` outside approved encrypted secret paths.

- [x] **Fix OpenTelemetry ingest secret leak (`/tmp/otel-env`) and standardize secret env rendering with `sops.templates`.**
  - **Context:** `hosts/main/default.nix:262-264` writes decrypted secret to `/tmp/otel-env` (default umask can make it world-readable).
  - **Do this:** replace shell preStart plumbing with `sops.templates` (or `LoadCredential`), set proper owner/mode, and source from `/run/secrets-rendered/...`.
  - **Design follow-up:** move this pattern into `modules/nixos/profiles/observability.nix` so all ingest-auth consumers inherit the safe behavior.

- [x] **Fix module topology bug: remove misleading global profile imports or gate profiles with options.**
  - **Context:** `modules/nixos/default.nix` imports unconditional profiles (`desktop`, `nvidia-prime`, `security`, `base`, `user`) for all hosts; host files also import profiles explicitly, creating redundancy and hidden closure bloat (headless hosts inherit desktop/NVIDIA stack unintentionally).
  - **Do this (recommended):** keep only option-declaring modules globally (`observability`, `services/hardened`, `systemd-failure-notify`) and let each host import intended profiles explicitly.
  - **Alternative:** add `profiles.<name>.enable` gates to all affected profiles.
  - **Included cleanup:** remove redundant `nvidia-prime` import in `hosts/main/default.nix:16` after topology fix.

- [x] **Complete homeserver sops bootstrap identity wiring (`.sops.yaml`) and make it fail-loud.**
  - **Context:** `&homeserver_host` is commented; first boot decryption can silently fail until deploy time.
  - **Do this:** add homeserver age key mapping, run `sops updatekeys`, document bootstrapping sequence, and add invariant/pre-deploy check that errors when homeserver host identity is missing.

- [x] **Add at least one recovery SSH key to `lib/pubkeys.nix` and document recovery procedure.**
  - **Context:** single-key setup is a lockout risk for initrd unlock and host recovery.
  - **Done:** added `recovery@main` ed25519 key (`~/.ssh/id_ed25519_recovery`). All auth surfaces consume `lib/pubkeys.nix`: initrd SSH (port 2222, LUKS unlock), main/homeserver/homeserver-vm/vm SSH, and installer root.
  - **Recovery procedure:**
    1. Retrieve `id_ed25519_recovery` from offline storage (Vaultwarden secure note or USB).
    2. Boot fails TPM unlock → initrd SSH on port 2222 is available.
    3. `ssh -i /path/to/id_ed25519_recovery -p 2222 root@<host-ip>` → enter LUKS passphrase.
    4. Host boots normally; follow up with `nh os switch` to redeploy if config drift.
  - **Key rotation:** generate new key, replace entry in `lib/pubkeys.nix`, rebuild and deploy all affected hosts, then retire old private key from offline storage.
  - **Store `~/.ssh/id_ed25519_recovery` offline** (Vaultwarden secure note or encrypted USB). The copy on `main` is useless during a lockout — offline storage is the only copy that matters.

---

## P1 — High Priority Reliability, CI, and Operational Safety

- [x] **Re-enable deploy-rs rollback safety (`magicRollback = true`) on deploy nodes.**
  - **Context:** current `magicRollback = false; autoRollback = false` raises outage risk if SSH/firewall deploys fail.

- [x] **Fix CI path-filter wiring so VM smoke actually runs, and smoke test edits retrigger smoke.**
  - **Context:** `.github/workflows/nix.yml` uses `needs.changes.outputs.vm` but `changes` does not set `vm`; `tests/` path changes do not trigger smoke.
  - **Do this:** add proper VM path filter output and include `tests/` in relevant regex.

- [x] **Ensure flake-update auto-merge cannot bypass required checks.**
  - **Context:** `flake-update.yml` auto-merges update PRs; safety depends on branch protection.
  - **Done:** added `merge-gate` job to `nix.yml` that consolidates all checks (flake-check, invariants, closure-diff, smoke-test) into a single required status. Configure branch protection: Settings → Branches → `main` → require status check `merge-gate`. smoke-test and closure-diff are allowed to be skipped (conditional jobs); flake-check and invariants must succeed.

- [x] **Add `cachix push` in CI after successful builds.**
  - **Context:** current CI appears to consume cache but does not seed it, causing avoidable rebuild cost on subsequent runs.

- [x] **Confirm whether Cachix substituters are wired where expected for local rebuild acceleration.**
  - **Done:** it wasn't wired. Added the integration and wired private keys through sops secrets.

- [x] **Upgrade `cachix/install-nix-action` to a supported major release.**
  - **Context:** workflow references older major (`v27`) while newer major exists.

- [x] **Add explicit KVM availability fail-fast in smoke tests.**
  - **Context:** smoke relies on KVM; missing `/dev/kvm` can cause confusing failures/timeouts.

- [x] **Derive `scripts/closure-diff.sh` repo reference from `$GITHUB_REPOSITORY`.**
  - **Context:** currently hardcoded owner/repo makes forks/renames fragile.

- [x] **Keep cold-install guidance explicit: `reinstall-homeserver.sh --no-substitute-on-destination` is install-only.**
  - **Context:** this is reasonable for first install but slower than normal deploy workflow.
  - **Do this:** document transition to `deploy-rs` / `nh os switch` after bootstrap.

- [x] **Strengthen fail2ban policy and enforce it with invariants on SSH hosts.**
  - **Context:** current policy (`maxretry = 5`, short bantime) is permissive.
  - **Do this:** lower retry threshold (for example 3), use incremental ban backoff, and add invariant check where SSH is enabled.

- [x] **Add timeout to `tailscale-cert.service` startup behavior.**
  - **Context:** current polling loop can run forever when Tailscale is unhealthy.
  - **Do this:** set service timeout/fail-fast behavior (`TimeoutStartSec` or equivalent bounded retry).

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

- [x] **Tighten pre-commit plaintext secret allowlist trust model.**
  - **Context:** hook checks staged file content but reads allowlist from working tree, which can weaken trust in edge cases.

- [x] **Add `shellcheck` to pre-commit hooks.**
  - **Context:** `shfmt` exists; linting shell semantics catches additional issues. (Also added to CI)

- [x] **Extend ACL generator tests beyond tag-owners to rule behavior.**
  - **Context:** current tests focus on tag owners; rule list and non-Tailscale-host behavior should be covered.
  - **Do this:** assert generated rules and assert hosts without `tailscale.tag` produce no tag ownership entries.

- [x] **Add invariant enforcing that `boot.initrd.secrets` points only to sops-managed secret paths.**
  - **Context:** prevents regressions to in-tree plaintext key material.

---

## P2 — Medium Priority Maintainability & Reproducibility

- [x] **Extract shared host sops/user wiring (`profiles/sops-base.nix` or equivalent).**
  - **Context:** repeated host boilerplate for `sops.defaultSopsFile`, format, `age.sshKeyPaths`, and user authorized-key wiring.

- [x] **Extract shared Restic profile and actually use host `backup.class`.**
  - **Context:** backup blocks are duplicated across `main`, `homeserver`, and `homeserver-vm`; `backup.class` exists in registry but is not used.

- [x] **Unify network identity source of truth (`lib/hosts.nix` vs `lib/network.nix`).**
  - **Context:** `tailnetFQDN` appears in multiple places.
  - **Do this:** derive network info from host registry or remove duplicate field.

- [x] **Add typed schema validation for `lib/hosts.nix` entries.**
  - **Context:** mixed-shape entries are filtered by presence checks, so malformed data can be silently skipped.
  - **Do this:** define typed submodule schema with explicit optional fields (`nullOr`) and fail at eval time on invalid registry entries.

- [x] **Replace impure `builtins.getEnv "CI"` toggle in `home/profiles/workstation.nix`.**
  - **Context:** flakes evaluate purely by default; current pattern can silently misbehave.
  - **Do this:** pass pure toggle via `specialArgs` or explicit option.

- [x] **Export `home/profiles/desktop.nix` consistently in `flake.nix` home modules output.**
  - **Context:** currently imported by user config but not exported with corresponding profile module set.

- [x] **Reduce duplication in `home/users/user/{home,server,wsl}.nix` via shared common profile.**
  - **Context:** repeated git/zsh/session/state patterns across entry files.
