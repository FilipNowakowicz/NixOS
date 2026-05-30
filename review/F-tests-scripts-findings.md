# Review F — Tests, Validation Scripts, CI, Pre-commit

Domain: `tests/`, `scripts/`, `.github/`, `flake/checks.nix`, `pre-commit-hooks.nix`, `treefmt.nix`.

Verified-good baseline: this is a high-quality suite. The invariant tests (`tests/lib/invariants.nix`)
genuinely test that invariants FIRE on bad input (negative cases for SSH, backup, firewall, trusted-users,
static-IP). The secret scanners have real positive/negative fixtures. The smoke test does real HTTP
assertions against nginx, checks auth boundaries (401/404), and queries Prometheus for probe success.
The profile-hardening test asserts an actual `systemd-analyze security` score. The fail2ban test verifies
the nft ban rule is installed, not just the internal counter. Findings below are the gaps that remain.

---

## P0 — False confidence / CI gaps that let bugs through

### P0-1 — `systemd-failure-notify` is shipped, wired on two hosts, and silently broken — no test

`modules/nixos/services/systemd-failure-notify.nix:11,46-55` and used at
`hosts/main/default.nix:307` and `hosts/mac/default.nix:178`.

The notify script does `SERVICE_NAME="${SYSTEMD_UNIT%.*}"`, but:

- `SYSTEMD_UNIT` is **not** an environment variable systemd exports to `ExecStart`. It is empty.
- The template unit `notify-failure@.service` carries the failed service as the instance specifier
  `%i` (see the `Description=Notify on %i failure` line), but `ExecStart` never passes `%i` to the
  script (no argument, no `Environment=`). So even if `SYSTEMD_UNIT` were set, it would resolve to
  the notifier unit, not the failed unit.

Result: every failure notification logs `Service  failed unexpectedly` (empty name) and the desktop
notification, if any, names nothing. The feature appears to work (a unit fires) but conveys no
information. There is **no test at all** for this module, so the breakage is invisible.

Fix direction: pass the instance via `ExecStart=... %i` and read `$1` in the script (or
`Environment=FAILED_UNIT=%i`). Add a NixOS test: define a service that exits non-zero with
`onFailure`, assert the journal line from `systemd-failure-notify` contains the real unit name.

### P0-2 — The entire `observability/alerts.nix` ruleset is untested

`modules/nixos/profiles/observability/alerts.nix` defines 9 alert rules (DiskUsageHigh,
SystemdUnitFailed, ResticBackupStale/CheckStale, Lynis*, Vulnix*, BlackboxProbeFailed) with hand-written
PromQL. None are exercised. The smoke test asserts `probe_success` is queryable but never loads the rules
into Mimir's ruler or evaluates a single alert expression.

Why it matters: a typo in a metric name (`restic_last_backup_timestamp_seconds`,
`node_systemd_unit_state{state="failed"}`, `lynis_hardening_index`) or a malformed `expr` evaluates fine
as a YAML string and ships. The alert simply never fires — the worst failure mode for a monitoring rule,
because it looks healthy. The thresholds (26h/8d buffers) are also unverified against the actual timer
cadence.

Fix direction: add a test that boots the observability stack, writes the rules file to the ruler, and
either (a) uses `cortextool/mimirtool rules check` to lint syntax + metric-name plausibility, or (b)
pushes synthetic series that breach each threshold and asserts the alert moves to firing via the ruler
API. At minimum, a `promtool check rules` (or `amtool check-config` for the alertmanager YAML) over the
generated files would catch syntax/label errors cheaply and could run in the `light` lane.

### P0-3 — `nix.yml` merge-gate is the required status, but it cannot fail when a test matrix leg fails-fast-disabled and another job is `skipped` due to a planner bug

`.github/workflows/nix.yml:468-547`. The gate's `require_when_planned` enforces "planned ⇒ success,
not-planned ⇒ skipped". This correctly couples the gate to `ci-plan.sh`. But the coupling means the gate's
correctness is entirely delegated to `ci-plan.sh`: if the planner **under-selects** (marks `tests=false`
when a security-relevant module changed), the gate happily passes because the job was correctly skipped per
the (wrong) plan. `test-ci-plan.sh` only checks a fixed set of representative paths; it does not assert the
inverse for every module/host, and several real modules have **no planner rule** (see P1-4). An
under-selecting planner therefore produces a green required check while shipping an untested change.

Fix direction: make `test-ci-plan.sh` enumerate every path under `modules/nixos/` and `hosts/*/` and
assert each maps to at least one host/test selector (fail on any path that selects nothing beyond
eval+lint). This converts "unknown module" from a silent under-select into a CI failure. (The
`unknown_module_changed` catch-all in `ci-plan.sh:149` already tries to do this for `modules/`, but **not**
for `hosts/installer/`, `home/` subtrees beyond the listed ones only partially, and there is no test that
the catch-all itself stays wired.)

### P0-4 — Weekly `flake.lock` auto-merge trusts a gate that skips the heavy security tests on a lock-only diff... but actually runs them; verify the gate **blocks** on `tests`

`.github/workflows/flake-update.yml:66-71` enables auto-merge. `ci-plan.sh:103-107` selects all hosts +
all tests for a `flake.lock` change, and `test-ci-plan.sh:106-110` asserts this. So far so good — the lock
bump does run profile + smoke tests. **However**, auto-merge with `--squash` will merge the moment the
_required_ status (merge-gate) is green. The smoke/profile `tests` job is in `merge-gate.needs`, so it is
gated. The remaining risk is `continue-on-error`/advisory jobs: `closure-diff` and the cache-push steps are
**not** in the gate (correct), but there is **no CVE scan in the gate at all** (see P1-1). A weekly lock
bump that pulls in a newly-CVE'd package will auto-merge silently because `cve-reports` runs in no workflow.

Fix direction: either add a `vulnix`/`cve-reports` job to `nix.yml` and include it in `merge-gate.needs`,
or explicitly accept the risk in `docs/security.md`. Today the `cve-reports` validate target and the
`VulnixCveFound` alert exist but nothing runs them in CI, so the only CVE signal is a runtime alert on a
host that may not be deployed yet.

---

## P1 — Significant coverage gaps

### P1-1 — CVE scanning exists but runs in no workflow

`scripts/validate.sh:171-174` (`cve-reports`), `flake/checks.nix:412-423` (`cveReportPackagesFor`),
`lib/cve-checks.nix`. There is a fully-built CVE report machinery and a `vulnix` tool in the dev shell, but
grep of `.github/workflows/` shows no job invokes `cve-reports` or `vulnix`. Security regressions from
dependency bumps are invisible until a deployed host's `VulnixCveFound` alert fires. See P0-4.

### P1-2 — No test that impermanence actually loses state on reboot

`flake/checks.nix:118-147` (`mainBackupPathsArePersisted`) statically checks that backup paths are a subset
of persisted paths — good, but it is a pure-eval invariant. There is **no booted test** proving the
ephemeral-root rollback works: that a file written outside `/persist` is gone after a reboot, and that a
file under `/persist` survives. The whole `main` storage model (rollback-root.service, @root-blank snapshot)
is the host's defining security property and is entirely untested in CI. The `installer` host is also
completely untested.

Fix direction: a NixOS test using the `nixos-test` driver with two boots (`machine.shutdown()` /
`machine.start()`) asserting tmpfs/rollback semantics on a minimal impermanence config.

### P1-3 — No test for sops secret decryption on any host

The `*-sops-bootstrap` checks (`flake/checks.nix:370-384`) only assert the pre-baked host-key `.enc` files
_exist on disk_ — they never decrypt anything. No test verifies that a host can actually decrypt a secret
with its SSH host key, that `boot.initrd.secrets` paths resolve, or that the `restic_repository` /
`grafana adminPasswordFile` secrets land at `/run/secrets/*` at runtime. The smoke test deliberately
_replaces_ sops secrets with in-store test files (`homeserver-gcp-smoke.nix:16-20`), so it proves the
opposite — that the wiring works _without_ sops. A broken `.sops.yaml` key group would pass every check
here and only fail at deploy time.

### P1-4 — Modules with zero test coverage

Enumerating `modules/nixos/`:

- Tested (directly or via smoke): `services/hardened.nix`, `profiles/security.nix` (fail2ban only),
  `profiles/observability/*` (collectors/backends/nginx via smoke + profile-observability).
- **Untested**: `services/systemd-failure-notify.nix` (P0-1), `profiles/observability/alerts.nix` (P0-2),
  `profiles/backup.nix` (prune-class logic — only the _result_ is checked by the host invariant, not the
  class→pruneOpts mapping in the module), `profiles/impermanence-base.nix` (P1-2),
  `profiles/microvm-guest.nix`, `profiles/machine-dev.nix` (the broad-passwordless-sudo exception —
  security-sensitive, no test that it's scoped to the intended hosts), `profiles/desktop.nix`,
  `profiles/observability-client.nix` (only the username invariant), `hardware/nvidia-prime.nix`,
  `profiles/nix-trusted-users.nix`, `profiles/meta.nix`, `profiles/sops-base.nix`, `profiles/user.nix`,
  `profiles/base.nix`.
- **Hosts with no booted/closure-level behavioral test**: `installer` (no closure built in CI at all —
  `ci-plan.sh` has no `installer` rule, so changes to it run only eval+lint).

### P1-5 — `security.nix` kernel hardening sysctls and the SSH hardening settings are never asserted at runtime

`modules/nixos/profiles/security.nix:60-69` sets 8 sysctls (`kernel.unprivileged_bpf_disabled`,
`accept_redirects`, etc.) and `:24-31` sets `PermitRootLogin=no`, `PasswordAuthentication=false`. The only
security-profile test (`profile-security.nix`) covers fail2ban exclusively. Nothing asserts the sysctls are
actually live (`sysctl kernel.unprivileged_bpf_disabled` == 1) or that sshd rejects password auth. A future
refactor that drops a sysctl or flips a default would pass CI.

### P1-6 — No test that `main` sudo actually requires a password at runtime

`flake/checks.nix:285-293` asserts `security.sudo.wheelNeedsPassword == true` as a pure-eval invariant, and
the `agentMaintenanceCommands` NOPASSWD allowlist (a genuine privilege-escalation surface per
`hosts/main/CLAUDE.md`) is never tested. A booted test that runs a non-allowlisted `sudo` as `user` and
asserts it prompts/denies, and that an allowlisted command runs NOPASSWD, would lock down the most
security-sensitive surface on the workstation. Currently a typo widening the allowlist regex would ship.

---

## P2 — Test quality / fragility

### P2-1 — Smoke test hard-fails on missing `/dev/kvm` instead of skipping

`tests/nixos/homeserver-gcp-smoke.nix:163-165` asserts `/dev/kvm` exists and raises otherwise. In CI the
`tests` job sets `system-features = ... kvm` and GitHub's larger runners may or may not expose KVM; a
runner without `/dev/kvm` turns this into a hard test failure (red merge-gate) rather than a skip. The
other profile tests don't gate on KVM, so this one is uniquely brittle to runner capability. Consider a
`pytest`-style skip or driver-level guard so the _absence_ of acceleration is distinguishable from a _real_
routing regression.

### P2-2 — `profile-observability` Test 2 asserts the auth header is _present_, not _correct_

`tests/nixos/profile-observability.nix:108-111` greps for `Authorization: Basic` in the captured request.
It never decodes the header to confirm the username is `telemetry` and the password matches
`passwordFile`. A bug that sent the wrong credentials (or a stale/blank password) would still contain
`Authorization: Basic` and pass. Decode base64 and assert `telemetry:test-secret`.

### P2-3 — ACL generator tests assert sorted output, which can mask ordering bugs

`tests/lib/acl.nix:90-97` (`testFirstAclDst`) expects a pre-sorted `dst` list. The generator itself sorts
(`lib/acl.nix:69`), so the test confirms the generator's own sort matches a sorted expectation — it cannot
catch a regression where the generator stops sorting but the _input_ happened to be sorted. Low risk
because `check-tailscale-acl-drift.sh` re-sorts with `jq -S` before diffing the live policy, but the
drift check only runs daily and needs API credentials, so it is not a PR-time guard.

### P2-4 — `scan-plaintext-secrets` pattern is byte-literal and defeatable by encoding/splitting

`scripts/scan-plaintext-secrets.sh:13` (and the identical pre-commit pattern at
`pre-commit-hooks.nix:29`) matches literal token shapes. The test fixture (`scan-plaintext-secrets.nix`)
even constructs the AKIA key at runtime "so the source file itself does not match" — which is exactly the
evasion a careless committer would do unintentionally (base64-encoding a secret, splitting a key across
lines, or storing it as `\x`-escapes). The scanner is a tripwire, not a guarantee, and the test only proves
it catches the un-obfuscated happy/sad paths. This is acceptable for a tripwire but should be documented as
such; a high-entropy/`gitleaks`-style detector would catch the encoded cases the regex cannot.

### P2-5 — Two parallel secret-scanners with drifting patterns

`scripts/scan-plaintext-secrets.sh:13` and `scripts/check-secrets-directory.sh:74-84` use **different**
token regexes (the latter adds `ya29.`, `sk-`, `glpat-`, `age-secret-key-`; the former adds `AIza`,
`xox`-with-shorter-bound, and the generic `*api_key*=` heuristic). The pre-commit hook
(`pre-commit-hooks.nix:29`) duplicates the first pattern inline as a _third_ copy. These three will drift.
A token shape covered by one but not the others creates a false sense of coverage. Factor the pattern into
a single shared file sourced by all three.

### P2-6 — `lib/generators.nix` `toAlloyHCL` number/float rendering is untested

`lib/generators.nix:16-18` renders ints/floats via `toString`. No `toAlloyHCL` test passes a number
(generators.nix tests only cover strings/bools/lists/blocks/refs). `toString 1.5` and `toString 12` are
fine, but `toString` on a float like `0.5` and especially the empty-attrs / single-key-attrs edge of the
inline-object branch are unexercised. Low severity; add a numeric attribute case.

---

## P3 — Future tests worth adding

- **P3-1 — anonymous specialisation isolation.** `hosts/main/anonymous.nix` is a security-critical amnesic
  boot target (tmpfs home, Tailscale/SSH/observability/backups disabled, Mullvad lockdown, Tor proxy). It
  has no test. A closure-level assertion that the specialisation config disables `services.tailscale`,
  `services.openssh`, `profiles.observability`, and the restic backups — and forces
  `checkReversePath = "strict"` — would prevent a regression that silently re-enables a deanonymizing
  service. This is pure-eval and cheap; it belongs in `flake/checks.nix` as an invariant set.
- **P3-2 — Mullvad/Tailscale coexistence.** The three load-bearing mechanisms (nftables mark, bypass
  routing service, loose rpfilter) are documented as fragile. An invariant asserting all three exist on
  `main` (and are absent in the anonymous spec) would guard the documented gotcha.
- **P3-3 — backup restore.** No test restores a restic snapshot. A test that backs up a fixture dir and
  restores it in the same VM would prove the repo password/env wiring end-to-end (complements P1-3).
- **P3-4 — treefmt coverage of YAML/TOML.** `treefmt.nix` formats nix/sh/md/prettier-defaults only. The
  `.github/workflows/*.yml`, `.sops.yaml`, and `vulnix-whitelist.toml` are unformatted/unvalidated. Add
  `yamlfmt`/`taplo` or at least a `actionlint` hook for the workflow YAML (a malformed `if:` expression in
  `nix.yml` currently fails only at runtime).
- **P3-5 — pre-commit ⇄ CI parity test.** The `light` lane comment (`scripts/validate.sh:113-116`) asserts
  pre-commit hooks are "already covered" by CI jobs, by prose. Nothing enforces that the hook set and the
  CI lint set stay in sync. A small test comparing the two lists would prevent a hook being added locally
  but never enforced in CI (or vice versa).
- **P3-6 — `actionlint` / pinned-action audit.** Actions are SHA-pinned (good). No CI step verifies new
  PRs keep them pinned; an `actionlint` or `zizmor` run would.
