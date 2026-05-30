# Fix context — flake entry point & lib/

Self-contained brief for a future fix agent. Each item: code excerpt, exact
issue, concrete fix, and the validation command. Do not run `nix eval`/`nix build`
of the whole flake blindly — use the targeted commands given.

Repo root: `/home/user/nix`. Reach the dev shell with `nix develop` (provides
`statix`, `deadnix`, `deploy-rs`, etc.).

## Status after PR 62

- `[PARTIAL]` FIX 1: workflow, stderr capture, and `homeserver-gcp` scan landed;
  advisories still warn rather than fail a merge-gating check.
- `[DONE]` FIX 2: `invariants-main-ci` landed.
- `[PARTIAL]` FIX 3: the initrd-secret claim is now documented as a native
  NixOS assertion; registry/impermanence invariant work remains open.
- `[DONE]` FIX 4: deploy confirm timeouts landed.
- `[DONE]` FIX 9 landed.
- `[OPEN]` FIX 5/6/10 remain open.
- `[DONE]` FIX 7/8 landed.

---

## FIX 1 (P0): Wire CVE scanning into CI and make it able to fail

### Current code

`lib/cve-checks.nix`:

```nix
mkCveCheck =
  hostName: closure:
  pkgs.runCommand "cve-check-${hostName}"
    { buildInputs = [ pkgs.vulnix ]; }
    ''
      echo "=== CVE Scan for '${hostName}' ===" > $out
      vulnix -R -j ${closure} 2>&1 >> $out || true
    '';
```

`flake/checks.nix:412-423`:

```nix
cveReportPackagesFor = system: ... {
  main = targetCveChecks.mkCveCheck "main" allNixosConfigs.main.config.system.build.toplevel;
};
```

`scripts/validate.sh:171-174` exposes `cve-reports` as a manual-only target.

### Issues

1. No CI workflow or cron ever builds `ciReports`; `merge-gate` does not depend
   on it. `grep -rn 'cve\|vulnix\|ciReports' .github/` returns nothing.
2. The check is non-failing by construction (`|| true`, exit 0).
3. `vulnix ... 2>&1 >> $out` has wrong redirection order: `2>&1` binds stderr to
   the _current_ stdout (the terminal) **before** `>> $out` redirects stdout, so
   vulnix's stderr (where it writes findings) escapes the report file.
4. Only `main` is scanned; `homeserver-gcp` (internet-adjacent) is omitted.

### Suggested fix

- Fix redirection to `> $out 2>&1` (or `&>> $out`).
- Add a _gating_ variant alongside the report, e.g. a whitelist-aware check that
  exits non-zero when vulnix reports findings not in an allowlist file:
  ```nix
  mkCveGate = hostName: closure: whitelist:
    pkgs.runCommand "cve-gate-${hostName}" { buildInputs = [ pkgs.vulnix ]; } ''
      if vulnix -R -w ${whitelist} ${closure} > $out 2>&1; then
        :
      else
        echo "vulnix found non-whitelisted advisories for ${hostName}" >&2
        cat $out >&2
        exit 1
      fi
    '';
  ```
- Add `homeserver-gcp` to `cveReportPackagesFor` using `ciNixosConfigs."homeserver-gcp"`.
- Add a scheduled job to `.github/workflows/` (mirror `flake-update.yml`'s cron
  block) that runs `bash scripts/validate.sh cve-reports`, and a `merge-gate`-
  reachable gate job that builds the gate derivations.

### Validation

```bash
nix build '.#legacyPackages.x86_64-linux.ciReports.main' --print-out-paths | xargs cat
# After adding a gate: a host with a known-vuln package must make the gate build fail.
```

---

## FIX 2 (P0): Pin `invariants-main` to the closure CI actually builds

### Current code

`flake/checks.nix:388-394`:

```nix
invariants-main = invariants.mkInvariantCheck "main" (
  commonSystemInvariants ++ mainAccessInvariants ++ mainExperienceInvariants
  ++ mainBackupInvariants ++ registryAssertionsFor "main"
) allNixosConfigs.main.config;     # <-- full closure
```

`scripts/validate.sh:143` builds `nixosConfigurations.main-ci...toplevel`, and
`flake/hosts.nix:101` defines `main-ci` with `profiles.ci = true; skipHeavyPackages = true`.

### Issue

The invariant validates `allNixosConfigs.main`, but CI ships `main-ci`. A
`profiles.ci`-gated change to a security option is invisible to the invariant.

### Suggested fix

Add a parallel check evaluated against the CI closure:

```nix
invariants-main-ci = invariants.mkInvariantCheck "main-ci" (
  commonSystemInvariants ++ mainAccessInvariants ++ mainExperienceInvariants
  ++ mainBackupInvariants ++ registryAssertionsFor "main"
) ciNixosConfigs.main-ci.config;
```

Add `invariants-main-ci` to the `light` target in `scripts/validate.sh`.
Alternatively, add an invariant asserting `profiles.ci` relaxes nothing
security-relevant.

### Validation

```bash
nix build '.#checks.x86_64-linux.invariants-main-ci'
bash scripts/validate.sh light
```

---

## FIX 3 (P1): Add the missing registry/sops/impermanence invariants

### Current code

`lib/invariants.nix:208-244` (`mkRegistryAssertions`) checks: hostName, OpenSSH
(deploy), restic (backup), tailscale (when tailscale/FQDN present), static IP.

`flake/checks.nix:370-384` (`mkSopsBootstrapCheck`) only checks that pre-baked
_key files_ exist — not that recipients in `.sops.yaml` match the registry.

CLAUDE.md claims: "`boot.initrd.secrets` MUST only point to sops-managed paths …
— enforced by an invariant check." **This invariant does not exist** (confirmed:
`grep -rn 'initrd.secrets' lib/ flake/ tests/lib/` is empty).

### Issues / suggested invariants to add

1. **initrd-secrets invariant (claimed but missing).** Add an invariant that
   every entry in `cfg.boot.initrd.secrets` resolves to a path under
   `/run/secrets/` (i.e. `config.sops.secrets.*.path`). Wire into `light`.
   ```nix
   {
     name = "initrd secrets come from sops";
     check = cfg:
       let bad = lib.filterAttrs (_: src: !(lib.hasPrefix "/run/secrets/" (toString src)))
                   (cfg.boot.initrd.secrets or {});
       in { passed = bad == {}; message = "initrd.secrets must be sops paths: ${toString (builtins.attrNames bad)}"; };
   }
   ```
2. **deploy-implies-tailnet.** In `mkRegistryAssertions`, when `hostMeta ? deploy`,
   also assert `cfg.services.tailscale.enable` (deploy path is Tailscale-only).
3. **impermanence-has-disko.** For hosts marked impermanent (registry could gain
   an `impermanent = true` field, or detect via `cfg.environment.persistence != {}`),
   assert the persist mount exists. `inventory-data.nix:162` already computes the
   boolean to reuse.
4. **sops recipient parity (build-time or script).** Add a check (script in
   `scripts/`, run in `light`) that every registry host has a matching
   `creation_rules` path_regex + age anchor in `.sops.yaml`.

### Validation

```bash
nix build '.#checks.x86_64-linux.invariants-main' '.#checks.x86_64-linux.invariants-mac' '.#checks.x86_64-linux.invariants-homeserver-gcp'
bash scripts/validate.sh light
```

---

## FIX 4 (P1): Per-host deploy tuning; reconsider magicRollback on mac

### Current code

`flake/deploy.nix:11-23`:

```nix
mkDeployNodes = nixosConfigs:
  lib.mapAttrs (name: cfg: {
    hostname = name;
    inherit (cfg.deploy) sshUser;
    magicRollback = true;
    autoRollback = true;
    remoteBuild = true;
    profiles.system = { user = "root"; path = deploy-rs.lib.${cfg.system}.activate.nixos nixosConfigs.${name}; };
  }) deployableHosts;
```

### Issue

No per-host `confirmTimeout` / `activationTimeout` / `magicRollback` override.
`mac` is impermanent + Tailscale-only-firewall, where magic-rollback's network
ping-back can roll back a _correct_ deploy if `tailscale0` comes up slowly.

### Suggested fix

Extend the registry `deploy` schema (`lib/hosts.nix:82-84` validator) to allow
optional `magicRollback`, `confirmTimeout`, `activationTimeout`, then:

```nix
magicRollback = cfg.deploy.magicRollback or true;
confirmTimeout = cfg.deploy.confirmTimeout or 30;
activationTimeout = cfg.deploy.activationTimeout or 240;
```

Set a longer `confirmTimeout` for `homeserver-gcp`, and evaluate
`magicRollback = false` for `mac`.

### Validation

```bash
nix build '.#deploy.nodes.mac.profiles.system.path' --no-link
nix eval '.#deploy.nodes' --apply 'n: builtins.attrNames n'
deploy-rs '.#mac' --dry-activate   # operator-only, requires hardware
```

---

## FIX 5 (P1): De-duplicate invariants between `flake/checks.nix` and `inventory-data.nix`

### Current code

`lib/inventory-data.nix:38-113` hand-reimplements main/homeserver invariants that
already exist in `flake/checks.nix:82-368`. They have drifted (inventory's main
backup check lacks btrbk + persistence depth).

### Suggested fix

Move the host invariant _lists_ (`mainAccessInvariants`, `mainBackupInvariants`,
`homeserverAccessInvariants`, `commonSystemInvariants`, the named check attrsets)
out of `flake/checks.nix` into a new pure `lib/host-invariants.nix` that takes
`{ lib, invariants }`. Have both `flake/checks.nix` and `inventory-data.nix`
import it so there is one definition.

### Validation

```bash
nix build '.#packages.x86_64-linux.inventory-data'
nix build '.#checks.x86_64-linux.invariants-main' '.#checks.x86_64-linux.invariants-homeserver-gcp'
bash scripts/validate.sh light
```

---

## FIX 6 (P1): Promote fail2ban hardening into the gate

### Current code

`lib/invariants.nix:104-127` implements `checkHardenedFail2ban`. It is consumed
only by `inventory-data.nix:21-22` (ungated). No `flake/checks.nix` invariant
uses it.

### Suggested fix

Add to `deployTargetAccessInvariants` (`flake/checks.nix:307`) or a new
`hardeningInvariants` list applied to SSH hosts:

```nix
{ name = "SSH hosts enforce hardened fail2ban";
  check = cfg: if !cfg.services.openssh.enable then mkResult true ""
               else invariants.checkHardenedFail2ban cfg; }
```

### Validation

```bash
nix build '.#checks.x86_64-linux.invariants-homeserver-gcp' '.#checks.x86_64-linux.invariants-main'
```

---

## FIX 7 (P2): Resolve the unused `ip` registry field

### Current code

`lib/hosts.nix:152-154` validates `ip`; `lib/invariants.nix:234-243` checks it;
`inventory-data.nix:157` projects it. **No host sets it and no module reads
`hostMeta.ip`.**

### Suggested fix

Either delete the field, its validator branch, its invariant, and the inventory
projection; **or** wire the intended consumer (likely `microvm-guest.nix` static
networking) and add a host that sets it. Decide and document in the schema header
comment (`lib/hosts.nix:19`).

### Validation

```bash
nix eval '.#nixosConfigurations.main.config.networking.hostName'
bash scripts/validate.sh light
deadnix . ; statix check .
```

---

## FIX 8 (P2): Add CI coverage for `installer-iso`, `control-center`, `tailscale-acl`

### Current state

`scripts/validate.sh hosts` builds only `main-ci`, `homeserver-gcp`, `mac`.
`installer-iso`, `control-center`, `tailscale-acl` are built by no CI job.

### Suggested fix

- Add to `scripts/validate.sh` a `package <name>` path that already exists
  (`flake/dev.nix` exposes them as `packages`), then add build steps to the
  `packages` job in `.github/workflows/nix.yml` (path-gated via `ci-plan.sh`):
  `nix build '.#packages.x86_64-linux.installer-iso'`,
  `.#packages.x86_64-linux.control-center`,
  `.#packages.x86_64-linux.tailscale-acl`.
- Add `tailscale-acl` eval to the `light` target.

### Validation

```bash
nix build '.#packages.x86_64-linux.installer-iso' --no-link
nix build '.#packages.x86_64-linux.control-center' --no-link
nix build '.#packages.x86_64-linux.tailscale-acl' --print-out-paths | xargs cat
```

---

## FIX 9 (P3): Add `nh`, `jq`, `git` to the default dev shell

### Current code

`flake/dev.nix:97-115` lists `nixd statix deadnix sops ssh-to-age python3 vulnix
direnv opentofu google-cloud-sdk` + deploy-rs/nixos-anywhere. `nh` (the
documented `rebuild` front-end), `jq`, and `git` are absent though the shellHook
uses `git`.

### Suggested fix

```nix
(with pkgs; [ nixd statix deadnix sops ssh-to-age python3 vulnix direnv
              opentofu google-cloud-sdk nh jq git ])
```

### Validation

```bash
nix develop -c sh -c 'command -v nh && command -v jq && command -v git'
```

---

## FIX 10 (P2): Make `mainBackupPathsArePersisted` derive roots from disko, not hard-code main's layout

### Current code

`flake/checks.nix:130-141` hard-codes `persistentRoots = [ "/home/" "/nix/" "/persist/" ]`.

### Suggested fix

Either scope this check name/comment to `main` explicitly (it already only runs
for `main`), or compute the persistent roots from the host's btrfs subvolume
mountpoints in disko so a future host with a rolled-back `/home` is caught.
Lowest-effort acceptable fix: add a comment + assertion that the host's disko
layout actually provides `@home`/`@persist` as non-rolled-back subvolumes.

### Validation

```bash
nix build '.#checks.x86_64-linux.invariants-main'
```

---

## Notes for the fixer

- `main` invariants run against `allNixosConfigs.main` (full), `homeserver-gcp`
  against `ciNixosConfigs.homeserver-gcp` (the disko-stubbed CI variant), `mac`
  against `allNixosConfigs.mac`. Keep this asymmetry in mind when adding checks.
- The `merge-gate` job (`.github/workflows/nix.yml:468-547`) requires
  `eval, checks-light, lint, packages, hosts, tests`. Anything you want gated
  must land in one of those jobs (most config invariants belong in `checks-light`
  via the `light` target in `scripts/validate.sh:112-131`).
- All listed fixes are expected to keep `statix check .` and `deadnix .` clean.
