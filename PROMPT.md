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

- [x] **Migrate flake structure to `flake-parts` (or equivalent per-system pattern).**
  - **Context:** current flake is functional but verbose and repetitive; migration improves scale to multi-arch and per-system ergonomics. (full multi-arch support split into a second goal)

---

## P3 — Documentation Tasks

- [x] **Document Neovim config trade-off (raw Lua via `xdg.configFile` vs HM `programs.neovim`).**
  - **Context:** current approach favors iteration speed but skips HM-level validation.

- [x] **Document network hardening trade-off where `checkReversePath = "loose"` is required.**
  - **Context:** current comment exists; make sure docs clearly capture rationale and security implication.

- [x] **Adopt signed commits and/or signed release tags.**
