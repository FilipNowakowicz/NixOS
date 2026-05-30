# Flake entry point & lib/ review — findings

Scope: `flake.nix`, `flake/*.nix`, `lib/*.nix`, plus the cross-references into
`.sops.yaml`, `hosts/`, `scripts/validate.sh`, and `.github/workflows/`.
All findings below evaluate and build fine today; they are correctness,
coverage, or fragility problems that static checks do not catch.

Severity legend: P0 silent failure/broken · P1 significant gap/security ·
P2 optimization · P3 future addition.

---

## P0 — CVE scanning is wired but never runs in CI

- **Where:** `flake.nix:206-209` (`legacyPackages.ciReports`), `flake/checks.nix:412-423`
  (`cveReportPackagesFor`), `lib/cve-checks.nix:1-19`, `scripts/validate.sh:171-174`
  (`cve-reports`), `.github/workflows/*`.
- **Problem:** `lib/cve-checks.nix` builds a `vulnix` report and is exposed as
  `legacyPackages.x86_64-linux.ciReports.main`. It is reachable only through
  `bash scripts/validate.sh cve-reports`, which is a manual target. Grepping the
  entire `.github/` tree for `cve`/`vulnix`/`ciReports` returns nothing — no job
  in `nix.yml`, no cron in `flake-update.yml`, and the `merge-gate` does not
  depend on it. The README (lines 309, 318) and CLAUDE.md advertise CVE health
  as an operated signal, but nothing scheduled actually produces or checks it.
  The system claims a security posture it does not enforce.
- **Why it matters:** A clean weekly flake bump can introduce a known-vulnerable
  package and merge with a green `merge-gate`. The "endgame, reproducible,
  secure" goal is silently unmet for the one dimension that needs automation.
- **Additional false-negative risk in the check itself:** `lib/cve-checks.nix:15`
  runs `vulnix -R -j ${closure} 2>&1 >> $out || true` and the comment says
  "Exit 0 to allow check to pass even if CVEs found." So even if it _were_ wired
  into CI it could never fail — it only ever produces a report artifact. There
  is no severity threshold, no whitelist mechanism, and no failing exit path.
  Also note the redirection order `2>&1 >> $out` sends stderr to the _old_
  stdout (the terminal), not into `$out`; vulnix writes findings to stderr, so
  the report file can end up nearly empty while the real output is discarded.
- **Fix direction:** Add a scheduled (weekly/daily) GitHub Actions job that
  builds `ciReports.main` and, separately, add a _gating_ CVE check that exits
  non-zero above a configurable severity with an explicit CVE allowlist file.
  Fix the redirection to `> $out 2>&1`. Scan every host closure, not just `main`
  (`homeserver-gcp` is the internet-exposed one and is omitted entirely).

---

## P0 — `homeserver-gcp` and `mac` host-key invariants run against a config that cannot represent real exposure correctly... but `main` invariants run against a _different_ closure than CI builds

- **Where:** `flake/checks.nix:388-405` vs `flake/hosts.nix:98-130`, `scripts/validate.sh:122,143`.
- **Problem:** `invariants-main` is evaluated against `allNixosConfigs.main.config`
  (the full workstation closure). But `scripts/validate.sh hosts` and CI build
  `nixosConfigurations.main-ci` (the `profiles.ci = true`, `skipHeavyPackages`
  variant). The invariant check and the thing CI actually ships are two
  different evaluations of `main`. If a `profiles.ci`-gated branch ever toggles
  a security-relevant option (firewall, sudo, ssh, usbguard), the invariant
  passes on the non-CI closure while CI builds and could deploy the variant that
  violates it. The invariant is not validating the artifact that ships.
- **Why it matters:** Invariants are the security backbone for `main` (no
  passwordless sudo, tailnet-only SSH, USBGuard deny-default). Validating a
  sibling evaluation undermines the guarantee. This is subtle precisely because
  both evaluate today.
- **Fix direction:** Either evaluate `invariants-main` against the same closure
  CI builds, or add a second invariant set `invariants-main-ci` against
  `ciNixosConfigs.main-ci.config` so both evaluations are pinned. At minimum add
  an invariant asserting that `profiles.ci` does not relax any access control.

---

## P1 — `main` deploy node has `autoRollback`/`magicRollback` but `main` is not a deploy target, while the impermanent hosts that _are_ deploy targets get a one-size rollback policy

- **Where:** `flake/deploy.nix:11-23`, `lib/hosts.nix` (`main` has no `deploy`).
- **Problem:** `mkDeployNodes` applies a single fixed policy to every deployable
  host: `magicRollback = true; autoRollback = true; remoteBuild = true;` with no
  per-host `confirmTimeout`/`activationTimeout`. `main` is correctly excluded
  (no `deploy` field), so the comment in `lib/hosts.nix:6` is honored. But:
  - **`mac` is an impermanence host** (README line 115; `hosts/mac/impermanence.nix`
    exists) deployed over Tailscale-only SSH. `magicRollback` works by having the
    _new_ config ping back over the network; on an impermanent host with a
    Tailscale-only firewall, if the new generation brings `tailscale0` up slightly
    slowly or a rule reorders, the magic-rollback probe can fail and auto-roll a
    _correct_ deploy. There is no per-host `confirmTimeout` to tune this.
  - **No `activationTimeout`/`confirmTimeout` anywhere** means deploy-rs defaults
    apply. For a remote GCP host behind Tailscale these defaults are often too
    tight and produce spurious rollbacks, or too loose and hang.
- **Why it matters:** A deploy that _works_ can be rolled back, or a broken one
  can hang, with no host-specific tuning. This is the classic "works in the lab,
  fragile in practice" deploy-rs trap.
- **Fix direction:** Add optional `deploy.confirmTimeout` / `deploy.activationTimeout`
  /`deploy.magicRollback` overrides to the registry schema and thread them through
  `mkDeployNodes` with sensible defaults (e.g. longer confirm timeout for the
  GCP host, consider `magicRollback = false` + manual confirm for the
  Tailscale-only impermanent mac).

---

## P1 — Invariant coverage gaps: several registry invariants that _should_ exist are absent

`lib/invariants.nix:208-244` (`mkRegistryAssertions`) is the only place the
registry is cross-checked against the built config. It checks hostName, OpenSSH
on deploy hosts, restic presence for backup hosts, tailscale enable, and static
IP. Missing, given the stated goals:

- **No "sops can actually decrypt" invariant.** Nothing asserts that every host
  with sops secrets has its age recipient present in `.sops.yaml`, nor that
  `boot.initrd.secrets` only points at `config.sops.secrets.X.path` (CLAUDE.md
  explicitly says this is "enforced by an invariant check" — I could not find
  that invariant in `lib/invariants.nix` or `flake/checks.nix`; verify it is not
  silently missing). A host added to the registry without a matching `.sops.yaml`
  creation_rule will eval/build fine and then fail to decrypt at boot.
  (`flake/checks.nix:370-384` only checks that _pre-baked key files exist_ for
  `mac`/`homeserver-gcp`, not that recipients match.)
- **No "impermanence host has disko configured" invariant.** README says `main`
  and `mac` are impermanent; `inventory-data.nix:162` even computes an
  `impermanence` boolean. Nothing asserts that an impermanent host actually mounts
  the persist subvolume or has disko, so a refactor could drop persistence
  silently.
- **No "every deploy target is on the tailnet" invariant.** Deploy is SSH-key-only
  over Tailscale (CLAUDE.md), but `mkRegistryAssertions` checks tailscale-enable
  only when `tailscale`/`tailnetFQDN` metadata is present. A deploy host without
  tailscale metadata would pass and then be unreachable by the documented path.
- **`main`'s access invariants are not applied to other workstation-class hosts.**
  `mac` shares `tag = "workstation"` and is a desktop, yet gets only
  `macAccessInvariants` (SSH tailnet-only). It does **not** get USBGuard
  deny-default or the nix-index/comma experience checks that `main` gets, even
  though it runs the same desktop profile. If that asymmetry is intentional it
  should be documented; otherwise it is a coverage gap.

**Fix direction:** Add the sops-recipient, impermanence-disko, and
deploy-implies-tailnet invariants. Re-confirm the initrd-secrets invariant
claimed in CLAUDE.md actually exists and is wired into `light`.

---

## P1 — `inventory-data.nix` re-implements `main`/`homeserver-gcp` invariants by hand, drifting from `flake/checks.nix`

- **Where:** `lib/inventory-data.nix:38-113` vs `flake/checks.nix:82-368`.
- **Problem:** The host-health block in `inventory-data.nix` open-codes its own
  copies of "main SSH tailnet-only", "USBGuard deny-default", "main local backup
  covers critical paths", and the homeserver port checks. These are _parallel
  reimplementations_ of the canonical invariants in `flake/checks.nix`, not calls
  into them. They have already drifted: `inventory-data.nix`'s main-backup check
  omits the `OnCalendar == "daily"`/`initialize`/btrbk policy depth that
  `flake/checks.nix:149-235` enforces, and it has no btrbk or
  `mainBackupPathsArePersisted` equivalent at all. The two will continue to drift
  whenever one is updated and the other is not.
- **Why it matters:** A reader trusts the inventory "health" signal that is
  exported to the homepage, but it is a weaker, separately-maintained copy of the
  real gate. False sense of coverage.
- **Fix direction:** Factor the host invariant _lists_ (`mainAccessInvariants`,
  `homeserverAccessInvariants`, etc.) out of `flake/checks.nix` into `lib/` so
  both the gating checks and `inventory-data.nix` consume one definition.

---

## P1 — `mainBackupPathsArePersisted` can be defeated by a parent-prefix false positive

- **Where:** `flake/checks.nix:136-143`.
- **Problem:** `isPersistent` returns true if a backup path is a prefix-child of
  _any_ persisted directory: `lib.any (d: lib.hasPrefix (d + "/") path) persistedDirs`.
  Combined with the `persistentRoots` `/home/`, `/nix/`, `/persist/` prefix test,
  this means literally any path under `/home/` is considered "persisted" even if
  it is not in the impermanence config — because on `main`, `@home` is a separate
  subvolume. That is correct _for `main`_, but the check is generic and a future
  host where `/home` _is_ rolled back would silently pass. The roots are
  hard-coded to `main`'s subvolume layout with no tie to the host's actual disko
  subvolumes.
- **Fix direction:** Derive the "persistent roots" from the host's btrfs subvolume
  set (disko) rather than hard-coding `/home//nix//persist/`, or scope this check
  explicitly to `main` and assert the subvolume layout it assumes.

---

## P2 — Registry fields defined and validated but never consumed anywhere

- **Where:** `lib/hosts.nix:19,152-154` (`ip`), schema doc lines 19, 27.
- **Finding:** The `ip` field is fully type-validated (`lib/hosts.nix:152`) and has
  a dedicated invariant (`lib/invariants.nix:234-243`) and an inventory projection
  (`inventory-data.nix:157`), but **no host defines `ip`** and **no module reads
  `hostMeta.ip`** (grep across `hosts/ modules/ home/` is empty). It is dead
  surface area carried as if load-bearing. The schema comment claims it is
  "consumed by host network config via hostMeta" — that consumer does not exist.
- **Contrast:** `hardware.diskById`, `tailnetFQDN`, `backup`, `homeManager`,
  `tailscale`, `status` are all genuinely consumed (verified). `status` is only
  consumed by `hosts/homeserver-gcp/status-page.nix` and the README table; it is
  otherwise informational, which is acceptable.
- **Fix direction:** Either delete the `ip` field + its invariant + inventory
  projection, or add a real consumer (it is presumably reserved for the
  microvm-guest path that is not yet wired). Document which.

---

## P2 — `installer` host and several flake packages have zero CI coverage

- **Where:** `flake/dev.nix:84-92` (`installer-iso`), `flake/dev.nix:74-82`
  (`tailscale-acl`), `flake/dev.nix:57-58` (`control-center`), `hosts/installer/`.
- **Problem:** Grepping CI + `validate.sh` for `installer`, `installer-iso`,
  `control-center`, `tailscale-acl` returns nothing. `scripts/validate.sh hosts`
  builds only `main-ci`, `homeserver-gcp`, `mac`. So:
  - `installer-iso` / `hosts/installer/default.nix` can break and no gate catches
    it until someone needs to reinstall — the worst possible time.
  - `control-center` (a first-class flake package) is never built in CI.
  - `tailscale-acl` is only validated by the _drift_ workflow against the live
    tailnet (`tailscale-acl-drift.yml`, daily cron); a PR that breaks ACL
    generation eval is not gated by `merge-gate`. (The `lib-acl` unit test does
    cover the generator, mitigating this somewhat.)
- **Fix direction:** Add `installer-iso` and `control-center` build steps to the
  `packages` job (path-gated), and add an eval of `tailscale-acl` to `light`.

---

## P2 — `commonSystemInvariants` is missing from `inventory-data` health and vice-versa; `commonAssertions` fail2ban check not in the gate

- **Where:** `lib/inventory-data.nix:18-35` includes a "SSH hosts enforce hardened
  fail2ban" assertion (`checkHardenedFail2ban`) that has **no counterpart** in
  `flake/checks.nix`. So fail2ban hardening is surfaced in the (non-gating)
  inventory health but is **not** a merge-gating invariant, despite README line
  123 listing fail2ban as a security feature with "automated E2E testing." The
  E2E test exists (`profile-hardening`), but the _config invariant_ is only in the
  ungated path.
- **Fix direction:** Promote `checkHardenedFail2ban` into the gated invariant set
  for deploy targets (it is already implemented in `lib/invariants.nix:104-127`).

---

## P2 — ACL generator: `autogroup:admin` break-glass `*:*` rule is unconditional and untestable per-host

- **Where:** `lib/acl.nix:83-90`.
- **Finding:** Every generated ACL appends an `autogroup:admin -> *:*` accept.
  This is deliberate (commented), but it means the carefully-derived
  `acceptFrom` port boundaries are fully bypassable by any admin-tagged node. If
  the owner's workstation is `autogroup:admin` (typical), the per-port rules for
  `workstation -> server` are effectively cosmetic for that account. That is a
  defensible choice, but the registry/ACL model presents itself as enforcing port
  boundaries when admins are exempt. No finding requires change; flag for the
  security model doc to state explicitly that admin nodes are unrestricted.
- **Edge case:** `tagOwners` assigns _every_ tag to `autogroup:admin` only
  (`lib/acl.nix:16-23`). There is no `tag:server` owner that is itself a server,
  and no `tagOwners` entry for groups — fine for the current 3-host fleet, but
  adding a host that should _not_ be admin-ownable has no representation.

---

## P3 — Generator `toAlloyHCL` emits trailing commas in lists and inline objects

- **Where:** `lib/generators.nix:24,30` (`[${...},]`, `${k} = ${...},`).
- **Finding:** Lists render as `[a, b,]` and inline attrsets as
  `{\n k = v,\n}`. The unit tests assert this exact shape (`tests/lib/generators.nix:78,106`),
  and Alloy/River tolerates trailing commas, so this is not a bug today. But it is
  a fragile assumption about a third-party config parser's lenience. If a future
  Alloy release tightens parsing, every generated component breaks at runtime with
  no Nix-level signal. Low priority; note as a known dependency on parser leniency.

---

## P3 — Dev shell omits tools referenced by documented workflows

- **Where:** `flake/dev.nix:96-124` (default shell).
- **Findings:**
  - `nh` is the documented rebuild front-end (`CLAUDE.md` "Deploy Commands",
    README deployment table: `nh os switch`). It is **not** in the default dev
    shell. The user relies on it being installed system-wide; a clean clone /
    new machine following the README cannot `rebuild`. Consider adding `nh`.
  - `jq` is not present, yet the inventory JSON, ACL JSON
    (`README.md:519-522` pipes the ACL build through `xargs cat`), and several
    `scripts/*.sh` likely parse JSON. Worth confirming scripts don't assume a
    system `jq`.
  - `git` is assumed present in the `shellHook` (`git rev-parse`) but not in
    `packages`; fine on NixOS, but the shell is "self-contained" only if `git`
    is added.
- **Fix direction:** Add `nh`, `jq`, and `git` to the default dev shell packages
  so the documented workflows work from a pure `nix develop`.

---

## P3 — `requirePaths` produces a misleading message shape

- **Where:** `flake/checks.nix:18-23`.
- **Finding:** When `missing == []`, the message is still computed as
  `"missing expected path(s): "` (empty tail). It is only surfaced on failure, so
  harmless, but the helper returns a "passed" result carrying a failure-phrased
  message. Minor; if `requirePaths` is ever reused in a context that logs the
  message on success, it will read wrong.

---

## Cross-reference summary (verified)

- Hosts in `hosts/`: `main`, `mac`, `homeserver-gcp`, `installer`. Registry
  (`lib/hosts.nix`): `main`, `mac`, `homeserver-gcp`. `installer` is
  intentionally out of the registry (utility ISO) and documented as such — OK,
  but it has no CI build (P2 above).
- `.sops.yaml` recipients: `user`, `main_host`, `homeserver_gcp_host`,
  `mac_host` — one per registry host plus user. Consistent. No automated check
  ties registry membership to `.sops.yaml` membership (P1 above).
- `flake/deploy.nix` deploy nodes are derived from `deploy`-bearing registry
  entries (`mac`, `homeserver-gcp`); `sshUser = "user"` for both, matching the
  registry. `main` correctly excluded. Consistent.
- Pre-baked sops bootstrap checks exist for `mac` and `homeserver-gcp`
  (`flake/checks.nix:407-409`); `main` has none because its key lives on
  `/persist`. Consistent with the impermanence model.
