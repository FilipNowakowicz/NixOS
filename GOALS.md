# Opus Audit Report — Unified Task Backlog

_Audit date: 2026-04-23. Scope: non-homeserver focused (main, VMs, WSL, lib, CI, secrets). Homeserver services are tracked in `HSGOALS.md`._

---

## P4 — Strategic / Optional (recommended when core backlog is stable)

- [ ] Add per-host system declarations for true multi-arch support.
  - **Context**: the flake can be refactored to perSystem without changing behavior, but host builds still assume a single global system. This task moves architecture selection into host metadata so each machine can target its own platform independently, e.g. x86_64-linux for desktops/servers and aarch64-linux for ARM hosts.

- [ ] **Add cross-system strategy (`--all-systems` checks / aarch64 readiness).**
  - **Context:** current evaluation is centered on `x86_64-linux`; future ARM/cloud targets benefit from earlier structure.

## Extra

- Hooks not tracked, other things?
- Long nix flake check on CI
