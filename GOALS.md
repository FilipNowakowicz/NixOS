# Opus Audit Report — Unified Task Backlog

_Audit date: 2026-04-23. Scope: non-homeserver focused (main, VMs, WSL, lib, CI, secrets). Homeserver services are tracked in `HSGOALS.md`._

---

## P2 — Medium Priority Maintainability & Reproducibility

- [x] **Lift hardcoded microvm external interface (`wlp0s20f3`) into host-level option or robust match rule.**
  - **Context:** interface renaming can break networking unexpectedly.

- [x] **Extract sops/Grafana file-substitution helper (`mkFileDirective`).**
  - **Context:** repeated inline pattern in observability module reduces readability.

- [x] **Consolidate overlapping Nix store optimization settings.**
  - **Context:** `nix.gc.automatic`, `nix.optimise.automatic`, and `nix.settings.auto-optimise-store` overlap in purpose.
  - **Do this:** keep one clear strategy.

- [x] **Improve `scripts/vm.sh` maintainability and SSH config integration model.**
  - **Context 1:** repetitive inline `printf "%-20s"` formatting logic.
  - **Context 2:** script mutates user `~/.ssh/config` directly (imperative behavior from Nix-built script).
  - **Do this:** extract formatting helper and prefer HM-managed `Include` fragment strategy.

- [x] **Normalize generator output style (Alloy trailing commas).**
  - **Context:** current rendering style is tolerated by parser but diverges from common River style.

- [x] **Unify package graph wiring to avoid split overlay/config maintenance.**
  - **Context:** top-level `pkgs = import nixpkgs { ... }` plus independent NixOS imports can drift when overlays/config evolve.

- [x] **Make host → Home Manager role/profile mapping explicit in registry.**
  - **Context:** profile choices are currently repeated inline in host definitions.

- [x] **Review and refine hardening overrides that disable syscall filter.**
  - **Context:** several services (`thermald`, `power-profiles-daemon`, `fwupd`, `bluetooth`) set `SystemCallFilter = null`, reducing baseline hardening value.
  - **Do this:** replace broad disablement with scoped allowlist profiles.

- [x] **Align ACL policy model with host metadata richness (or explicitly document minimal policy intent).**
  - **Context:** current ACL generation is intentionally simple; registry has richer metadata not yet consumed.

- [x] **Address reproducibility gray areas.**
  - ~~**Theme state:** `home/theme/active.nix` is imperatively changed by theme switch script.~~ **Resolved:** `git update-index --skip-worktree home/theme/active.nix` — file stays tracked (included in flake source, committed default survives fresh clone), but local writes from `theme-switch` are invisible to git. To commit a new default: `git update-index --no-skip-worktree home/theme/active.nix`, commit, re-apply skip.
  - **Hardware config lifecycle:** hand-maintained `hardware-configuration.nix` should have regeneration policy/date note.
  - **Timezone flexibility:** `Europe/Warsaw` is globally fixed; consider host-level override path.

---

## P3 — Documentation Tasks

- [x] **Document Neovim config trade-off (raw Lua via `xdg.configFile` vs HM `programs.neovim`).**
  - **Context:** current approach favors iteration speed but skips HM-level validation.

- [x] **Document network hardening trade-off where `checkReversePath = "loose"` is required.**
  - **Context:** current comment exists; make sure docs clearly capture rationale and security implication.

- [x] **Adopt signed commits and/or signed release tags.**

---

## P4 — Strategic / Optional (recommended when core backlog is stable)

- [ ] **Migrate flake structure to `flake-parts` (or equivalent per-system pattern).**
  - **Context:** current flake is functional but verbose and repetitive; migration improves scale to multi-arch and per-system ergonomics.

- [ ] Add per-host system declarations for true multi-arch support.
  - **Context**: the flake can be refactored to perSystem without changing behavior, but host builds still assume a single global system. This task moves architecture selection into host metadata so each machine can target its own platform independently, e.g. x86_64-linux for desktops/servers and aarch64-linux for ARM hosts.

- [ ] **Add cross-system strategy (`--all-systems` checks / aarch64 readiness).**
  - **Context:** current evaluation is centered on `x86_64-linux`; future ARM/cloud targets benefit from earlier structure.

## Extra

- Hooks not tracked, other things?
- Long nix flake check on CI
