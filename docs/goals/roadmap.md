# Roadmap & Backlog

Deferred and intentionally-not-yet-done work. Completed items are removed. Items
here are tracked with a trigger that justifies revisiting them, so the repo
avoids premature abstraction. Host-specific roadmaps live in
[`homeserver-goals.md`](homeserver-goals.md) and
[`macbook-goals.md`](macbook-goals.md).

---

## Near-Term Candidates

**Modules / hardening:** `systemd.oomd`, bootloader and console hardening parity
across hosts, datasource/backend coupling assertions, automatic failure-notify
attachment.

**Hosts:** age-key escrow, declarative `mac` travel mode, initrd/FIDO2 recovery
for `mac`, coredump storage policy review on `main`,
`config.specialisation`-based alternate boot entries (e.g. a gaming profile).

**Homeserver / GCP:** service-level disk quotas, Shielded VM / vTPM / integrity
monitoring in Terraform, metadata endpoint hardening, dedicated GCP network/VPC
model.

**Home Manager:** `firefox-private` profile parity, bat/base16 theme
provisioning, deduplicate runtime inputs for Waybar/Kitty/Swaybg/Hyprland, HM
fontconfig, GPG or secret-service defaults, migrate raw Neovim config into
`programs.neovim`.

---

## Cross-System / Multi-Arch Support

Status: postponed until the first non-`x86_64-linux` host is planned or added.

The active fleet is `x86_64-linux` only. The immediate structural change is
per-host `system` metadata in `lib/hosts.nix` (already in place); broadening
checks now would add CI and tooling complexity before there is a concrete second
architecture to validate.

Scope when revisited:

- `nix flake check --all-systems`
- `aarch64-linux` evaluation readiness
- Gating or refactoring x86-specific VM and test tooling

Trigger to revisit: a real ARM host is planned or added to `lib/hosts.nix`.

---

## Deferred Strategic Goals

### Full Service Composition DSL

Status: deferred. A DSL that emits Nginx locations, firewall rules, backup
paths, hardening, and Alloy scrape config could be useful, but premature
abstraction would hide important security and exposure decisions. Wait until
there are enough real services to reveal the right shape.

Trigger: two or three additional services repeat the same cross-cutting pattern
and the manual edits become error-prone.

### AppArmor Or Broader MAC Policy

Status: deferred. Mandatory access control can be valuable but has a high tuning
and maintenance cost. The current security model gets more immediate value from
systemd sandboxing, service-exposure discipline, and restore verification.

Trigger: a specific threat model or service requires confinement beyond systemd
hardening.

### Full Flake-Parts Modular Decomposition

Status: rejected for now. The repo already uses flake-parts where it helps.
Splitting the flake further would mostly be aesthetic at the current size.

Trigger: flake outputs become difficult to understand, or contributors
routinely touch unrelated output definitions by mistake.

---

## Homeserver Parked Ideas

Status: not active priorities; revisit if manual deploys or secret hygiene
become real pain points.

### Automated Deploy Pipeline

Why parked: the manual deploy flow is currently acceptable, and the repo already
has validation and smoke-test entrypoints without GitHub Actions automation.

Scope when revisited:

- Self-hosted GitHub Actions runner as a NixOS service
- Validation and smoke-test gating before deploy
- Ordered rollout for `homeserver-gcp` and then `main`

### Secret Rotation Ritual

Why parked: rotation is useful but largely procedural and only partly
automatable; the current setup does not justify prioritizing it over active
service and auth work.

Scope when revisited:

- Secret inventory with owner, trigger, and command path
- Rotation checklist through `sops` and deploy
- Optional Grafana visibility for secret-age metadata
  </content>
