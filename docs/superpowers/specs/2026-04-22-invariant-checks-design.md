# Configuration Invariant Checks Design

**Date:** 2026-04-22  
**Goal:** Add extensible `nix flake check` tests that validate host configuration against declared policies.

---

## Problem Statement

CLAUDE.md declares security policies:

- "Passwordless sudo is for VMs and dev machines only"
- "Homeserver has firewall enabled"

But nothing prevents accidental policy violations during refactors or copy-paste errors. Config and intent can drift silently until deployment.

**Solution:** Automated checks that run every `nix flake check`, catching drift immediately.

---

## Design

### Architecture

A `checks` output in `flake.nix` provides per-host invariant checks:

1. **Evaluation:** Each host's NixOS config is evaluated (reuses existing `mkNixos` logic)
2. **Assertion:** Specific config values are extracted and tested against predicates
3. **Derivation:** Each host produces a check derivation that passes/fails atomically
4. **Integration:** `nix flake check` runs all checks; failures block `nix flake check`

**Data flow:**

```
flake.nix (defines mkNixos)
    ↓
lib/invariants.nix (framework: mkInvariantCheck, assertion helpers)
    ↓
flake.nix checks output (per-host assertions)
    ↓
derivations (pass/fail per host)
    ↓
nix flake check (runs all, exit 0 if all pass)
```

### File Structure

**New file: `lib/invariants.nix`**

- Exports `mkInvariantCheck`: takes hostname and list of assertion objects, returns a check derivation
- Each assertion is `{ name: string; check: config → bool }`
- Output on failure: host name, assertion name, and reason (e.g., "main: no passwordless sudo — expected true, got false")

**Modified: `flake.nix`**

- Import `lib/invariants.nix`
- Add `checks.x86_64-linux` output with one check per host family:
  - `invariants-main`
  - `invariants-vm`
  - `invariants-homeserver-vm`
  - `invariants-homeserver`
  - `invariants-installer` (minimal)

### Initial Invariants

**All hosts:**

- `system.stateVersion` is set (sanity check; catches missing config)

**`main`:**

- `security.sudo.wheelNeedsPassword != false` (no passwordless sudo; CLAUDE.md requirement)

**`vm`, `homeserver-vm`:**

- `security.sudo.wheelNeedsPassword == false` (passwordless sudo enabled; inverse of main)

**`homeserver`, `homeserver-vm`:**

- `networking.firewall.enable == true` (firewall enabled; CLAUDE.md requirement)

**`installer`:**

- `system.stateVersion` is set (minimal; mostly a sanity check)

### Extensibility Model

To add a new invariant later:

```nix
invariants-main = mkInvariantCheck "main" [
  { name = "no passwordless sudo"; check = cfg => cfg.security.sudo.wheelNeedsPassword != false; }
  { name = "new assertion"; check = cfg => cfg.some.nested.value == expected; }
];
```

No framework changes needed. Assertions are simple predicates.

### Error Handling & Output

- **Pass:** Derivation succeeds silently
- **Fail:** Derivation fails with a clear message:
  ```
  error: invariant check failed on 'main'
    assertion: no passwordless sudo
    expected: true (wheelNeedsPassword != false)
    got: false
  ```
- **Missing config:** If a required config path doesn't exist, fail with:
  ```
  error: config path not found on 'vm'
    assertion: passwordless sudo enabled
    reason: security.sudo.wheelNeedsPassword is not set
  ```
- Exit code: 1 if any host fails, 0 if all pass

### Non-Goals / Future Work

- **VM boot testing** (use full `pkgs.nixosTest` later if needed)
- **Diff output** (simple error messages for now; add later)
- **Syncthing scope checks** (premature; add when this proves valuable)
- **Lanzaboote on main** (can add later as a separate invariant)

---

## Implementation Notes

- Assertions are evaluated **at flake check time**, not at build time (fast, no full system builds)
- Each host's config is evaluated once; assertions run on the evaluated config
- If a config value doesn't exist (e.g., a field is never set), the assertion should gracefully fail with a clear message
- The framework should be simple enough to understand in one sitting (under 50 lines of code)

---

## Testing the Implementation

1. Run `nix flake check` — should pass (all invariants are currently satisfied)
2. Intentionally break an invariant:
   - Edit `modules/nixos/profiles/vm.nix`, set `wheelNeedsPassword = true`
   - Run `nix flake check` — should fail on `invariants-vm`
3. Revert the change, run `nix flake check` — should pass again
4. Add a new invariant to `main` and verify it shows up in the check

---

## Success Criteria

- [ ] `nix flake check` includes 5 new check outputs (one per host family)
- [ ] All invariants pass on current config
- [ ] At least one deliberate failure (e.g., breaking sudo) produces a clear error message
- [ ] The framework is extensible: adding a new invariant requires only adding one line to an assertion list
- [ ] No changes to existing host configs (assertions should validate current state, not change it)
