# Goals

Active improvement goals for this flake. This document tracks work that still
fits the current architecture; outdated or intentionally deferred ideas belong
in `docs/backlog.md`.

## Principles

- Prefer goals that tighten consistency around the existing design instead of
  introducing new abstraction layers prematurely.
- Treat `main` and `homeserver-gcp` differently when their storage, threat
  model, or operational constraints differ.
- Prefer explicit policy and recovery documentation over broad "hardening"
  changes that are difficult to validate.

## Active Goals

| Order | Goal                         | Difficulty | Scope        | Why now                                                                                       |
| :---- | :--------------------------- | :--------- | :----------- | :-------------------------------------------------------------------------------------------- |
| 1     | Desktop declarativity review | Medium     | Home Manager | Clarifies where typed HM modules help and where raw dotfiles remain the right tradeoff.       |
| 2     | Recovery-path audit          | Hard       | `main`       | Validates that the current boot, unlock, and break-glass paths remain coherent under failure. |

## Goal Details

### 1. Desktop declarativity review

Decide intentionally where Home Manager modules help and where raw dotfiles are
still the better fit.

Implementation:

- Review Hyprland, Kitty, and adjacent desktop config that is currently managed
  as files.
- Keep raw files where theme generation, upstream syntax, or full-control needs
  make them the cleaner option.
- Move to typed HM options only where the merge behavior or validation is worth
  the loss of directness.

Acceptance:

- Desktop config management reflects deliberate tradeoffs instead of drift over
  time.

### 2. Recovery-path audit

Validate the full failure-handling story on `main`.

Implementation:

- Review TPM unlock, initrd SSH, Secure Boot state, persistence assumptions,
  backups, and scoped maintenance sudo as one system.
- Identify single points of failure and unclear operator steps.
- Turn any non-obvious recovery assumptions into short runbook notes.

Acceptance:

- The current boot and recovery design can be explained and exercised as a
  coherent system.
- Break-glass steps are explicit enough to trust during an actual incident.
