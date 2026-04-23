# Opus Audit Report — Unified Task Backlog

_Audit date: 2026-04-23. Scope: non-homeserver focused (main, VMs, WSL, lib, CI, secrets). Homeserver services are tracked in `HSGOALS.md`._

---

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

- [ ] **Review initrd SSH exposure risk model and add constraints if needed.**
  - **Context:** initrd firewall controls differ; port 2222 exposure depends on network posture.
  - **Do this (if threat model requires):** add tighter initrd network restrictions (for example flush-before-stage2/limited exposure) and document expected boot-network assumptions.
    "Result: the initrd SSH exposure is conditional in your current config, not always-on.

- main explicitly enables initrd SSH on port 2222 with keys from lib/pubkeys.nix, and
  uses a sops-injected initrd host key (hosts/main/default.nix:56-72,
  hosts/main/default.nix:307, lib/pubkeys.nix:1-4).
- This happens in stage 1, so normal host controls (networking.firewall,
  services.openssh.openFirewall = false, Tailscale posture) are not the protection boundary
  for initrd SSH (modules/nixos/profiles/security.nix:4-5, hosts/main/default.nix:121-129;
  upstream initrd-ssh.nix:31-37, initrd-ssh.nix:336-343).
- There is no repo-defined initrd firewall policy; upstream initrd networking/SSH
  modules don’t add one by default (initrd-network.nix:56-120, initrd-ssh.nix:26-128).
- In the evaluated config, initrd networking is likely not auto-addressed right now
  (networking.useDHCP = false, boot.initrd.systemd.network.networks = {}), so reachability
  of :2222 depends on boot-time network setup (e.g., kernel ip= or explicit initrd network
  config).

So your GOALS note is accurate: exposure depends on network posture. On an untrusted
L2/publicly reachable boot network, risk is materially higher; on a non-addressed or
isolated boot network, practical exposure is much lower."

- [ ] **Tighten pre-commit plaintext secret allowlist trust model.**
  - **Context:** hook checks staged file content but reads allowlist from working tree, which can weaken trust in edge cases.

- [x] **Add `shellcheck` to pre-commit hooks.**
  - **Context:** `shfmt` exists; linting shell semantics catches additional issues. (Also added to CI)

- [ ] **Extend ACL generator tests beyond tag-owners to rule behavior.**
  - **Context:** current tests focus on tag owners; rule list and non-Tailscale-host behavior should be covered.
  - **Do this:** assert generated rules and assert hosts without `tailscale.tag` produce no tag ownership entries.

- [ ] **Add invariant enforcing that `boot.initrd.secrets` points only to sops-managed secret paths.**
  - **Context:** prevents regressions to in-tree plaintext key material.

---

## P2 — Medium Priority Maintainability & Reproducibility

- [ ] **Extract shared host sops/user wiring (`profiles/sops-base.nix` or equivalent).**
  - **Context:** repeated host boilerplate for `sops.defaultSopsFile`, format, `age.sshKeyPaths`, and user authorized-key wiring.

- [ ] **Extract shared Restic profile and actually use host `backup.class`.**
  - **Context:** backup blocks are duplicated across `main`, `homeserver`, and `homeserver-vm`; `backup.class` exists in registry but is not used.

- [ ] **Unify network identity source of truth (`lib/hosts.nix` vs `lib/network.nix`).**
  - **Context:** `tailnetFQDN` appears in multiple places.
  - **Do this:** derive network info from host registry or remove duplicate field.

- [ ] **Add typed schema validation for `lib/hosts.nix` entries.**
  - **Context:** mixed-shape entries are filtered by presence checks, so malformed data can be silently skipped.
  - **Do this:** define typed submodule schema with explicit optional fields (`nullOr`) and fail at eval time on invalid registry entries.

- [ ] **Replace impure `builtins.getEnv "CI"` toggle in `home/profiles/workstation.nix`.**
  - **Context:** flakes evaluate purely by default; current pattern can silently misbehave.
  - **Do this:** pass pure toggle via `specialArgs` or explicit option.

- [ ] **Export `home/profiles/desktop.nix` consistently in `flake.nix` home modules output.**
  - **Context:** currently imported by user config but not exported with corresponding profile module set.

- [ ] **Reduce duplication in `home/users/user/{home,server,wsl}.nix` via shared common profile.**
  - **Context:** repeated git/zsh/session/state patterns across entry files.

- [ ] **Lift hardcoded microvm external interface (`wlp0s20f3`) into host-level option or robust match rule.**
  - **Context:** interface renaming can break networking unexpectedly.

- [ ] **Extract sops/Grafana file-substitution helper (`mkFileDirective`).**
  - **Context:** repeated inline pattern in observability module reduces readability.

- [ ] **Consolidate overlapping Nix store optimization settings.**
  - **Context:** `nix.gc.automatic`, `nix.optimise.automatic`, and `nix.settings.auto-optimise-store` overlap in purpose.
  - **Do this:** keep one clear strategy.

- [ ] **Improve `scripts/vm.sh` maintainability and SSH config integration model.**
  - **Context 1:** repetitive inline `printf "%-20s"` formatting logic.
  - **Context 2:** script mutates user `~/.ssh/config` directly (imperative behavior from Nix-built script).
  - **Do this:** extract formatting helper and prefer HM-managed `Include` fragment strategy.

- [ ] **Normalize generator output style (Alloy trailing commas).**
  - **Context:** current rendering style is tolerated by parser but diverges from common River style.

- [ ] **Unify package graph wiring to avoid split overlay/config maintenance.**
  - **Context:** top-level `pkgs = import nixpkgs { ... }` plus independent NixOS imports can drift when overlays/config evolve.

- [ ] **Make host → Home Manager role/profile mapping explicit in registry.**
  - **Context:** profile choices are currently repeated inline in host definitions.

- [ ] **Review and refine hardening overrides that disable syscall filter.**
  - **Context:** several services (`thermald`, `power-profiles-daemon`, `fwupd`, `bluetooth`) set `SystemCallFilter = null`, reducing baseline hardening value.
  - **Do this:** replace broad disablement with scoped allowlist profiles.

- [ ] **Align ACL policy model with host metadata richness (or explicitly document minimal policy intent).**
  - **Context:** current ACL generation is intentionally simple; registry has richer metadata not yet consumed.

- [ ] **Address reproducibility gray areas.**
  - **Theme state:** `home/theme/active.nix` is imperatively changed by theme switch script.
  - **Hardware config lifecycle:** hand-maintained `hardware-configuration.nix` should have regeneration policy/date note.
  - **Timezone flexibility:** `Europe/Warsaw` is globally fixed; consider host-level override path.

---

## P3 — Documentation Tasks

- [ ] **Update README USBGuard wording to match actual allowlist reality.**
  - **Context:** current wording implies complete deny-default coverage while actual whitelist may be narrower (for example only Logitech receiver).

- [x] **Extend README secure-boot/encryption section with initrd SSH recovery path details.**
  - **Context:** TPM unlock is documented; initrd SSH fallback should be explicit.
  - **Done:** recovery procedure documented inline in P0 recovery-key task above.

- [ ] **Add README/CLAUDE callout for sops bootstrap chicken-and-egg and host-key rotation implications.**
  - **Context:** host SSH key changes require corresponding `sops updatekeys` workflow.

- [ ] **Clarify VM decision rule in top-level `CLAUDE.md`.**
  - **Context:** microvm vs archived QEMU testing workflow distinction is easy to misread.
  - **Do this:** add direct rule (microvm default; QEMU only for specific impermanence/LUKS validation path).

- [ ] **Update `hosts/homeserver/CLAUDE.md` account bootstrap note.**
  - **Context:** one-time `SIGNUPS_ALLOWED` flow should be clearly marked as bootstrap-only; mention Tailscale-only exposure assumption.

- [ ] **Update `hosts/homeserver-vm/CLAUDE.md` cert persistence note.**
  - **Context:** self-signed cert is generated once and persists under `/persist`; replacement is manual.

- [ ] **Clarify purpose/location of `PROMPT.md`.**
  - **Context:** currently appears scratch-like.
  - **Do this:** either document as reusable template or move to a dedicated prompt directory.

- [ ] **Create architecture doc (`docs/architecture.md`) with host → profiles → modules → lib graph.**
  - **Context:** module topology confusion contributed directly to current import bug.

- [ ] **Document Neovim config trade-off (raw Lua via `xdg.configFile` vs HM `programs.neovim`).**
  - **Context:** current approach favors iteration speed but skips HM-level validation.

- [ ] **Document network hardening trade-off where `checkReversePath = "loose"` is required.**
  - **Context:** current comment exists; make sure docs clearly capture rationale and security implication.

---

## P4 — Strategic / Optional (recommended when core backlog is stable)

- [ ] **Migrate flake structure to `flake-parts` (or equivalent per-system pattern).**
  - **Context:** current flake is functional but verbose and repetitive; migration improves scale to multi-arch and per-system ergonomics.

- [ ] **Add cross-system strategy (`--all-systems` checks / aarch64 readiness).**
  - **Context:** current evaluation is centered on `x86_64-linux`; future ARM/cloud targets benefit from earlier structure.

- [ ] **Add `nixos-generators` image path for GCE (matching long-term homeserver/cloud goals).**

- [ ] **Introduce service composition abstraction for repeated service wiring.**
  - **Context:** can gradually unify hardening, backup, observability, and firewall concerns in one composable interface.

- [ ] **Expand typed generator approach to additional domains (for example nginx vhosts/timers).**

- [ ] **Stand up self-hosted CI runner on homeserver when available.**
  - **Context:** enables heavier tests, better cache warmup, and deploy-oriented workflows.

- [ ] **Adopt signed commits and/or signed release tags.**

- [ ] **Create secret rotation ritual/checklist + age/rotation observability metric.**
