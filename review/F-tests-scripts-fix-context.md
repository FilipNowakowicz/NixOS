# Fix Context — Tests, Scripts, CI, Pre-commit

Self-contained prompt for a fix agent. Each item: code excerpt, exact issue, concrete fix, validation
command. Work in the flake at repo root. Dev shell: `nix develop`. Do not run `nix eval`/`nix build` of
unrelated targets unless validating.

## Status after PR 62

- `[DONE]` P0-1, P0-2, and installer CI coverage from P0-3/P1-4 landed.
- `[DONE]` P1-6 and P2-1 landed.
- `[PARTIAL]` P0-4/P1-1 landed as scheduled and `flake.lock` PR CVE reports,
  but advisory findings warn rather than fail a merge-gating check.
- `[DONE]` P2-5 landed; the main scanner, pre-commit hook, and
  secrets-directory checker now share one pattern.
- `[OPEN]` P1-2, P1-3, P1-5, P2-2, P2-6/P2-3, P3-1/P3-2, and
  P3-4/P3-6 remain open.

---

## FIX P0-1 — `systemd-failure-notify` never knows which service failed

### Current code

`modules/nixos/services/systemd-failure-notify.nix`:

```nix
notifyScript = pkgs.writeScript "systemd-failure-notify" ''
  #!/usr/bin/env bash
  SERVICE_NAME="''${SYSTEMD_UNIT%.*}"
  ...
'';
...
systemd.units."notify-failure@.service" = {
  text = ''
    [Service]
    Type=oneshot
    ExecStart=${pkgs.bash}/bin/bash ${notifyScript}
    ...
  '';
};
systemd.services = lib.mkMerge (
  map (serviceName: {
    "${serviceName}".onFailure = [ "notify-failure@${serviceName}.service" ];
  }) cfg.services
);
```

### Issue

`SYSTEMD_UNIT` is not exported by systemd to `ExecStart`; it is empty. The failed unit name is available
only as the template instance `%i`, which is never passed to the script. Every notification reads
`Service  failed` with a blank name. No test exists, so the breakage is invisible.

### Fix

Pass the instance explicitly and consume it as `$1`:

```nix
notifyScript = pkgs.writeShellScript "systemd-failure-notify" ''
  set -euo pipefail
  SERVICE_NAME="''${1%.*}"
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$TIMESTAMP] Service $SERVICE_NAME failed unexpectedly" \
    | ${pkgs.systemd}/bin/systemd-cat -t systemd-failure-notify -p warning
  if [[ -n "''${DISPLAY:-}" || -n "''${WAYLAND_DISPLAY:-}" ]]; then
    ${pkgs.libnotify}/bin/notify-send -a systemd -u critical \
      "Service Failed" "$SERVICE_NAME failed at $TIMESTAMP" 2>/dev/null || true
  fi
'';
# unit:
ExecStart=${notifyScript} %i
```

(`%i` is already URL-unescaped for simple unit names; for fully-general names use `%I`.)

### Add test — `tests/nixos/profile-systemd-failure-notify.nix`

```nix
{ nixpkgs, system }:
let pkgs = import nixpkgs { inherit system; };
in (import "${nixpkgs}/nixos/lib/testing-python.nix" { inherit system pkgs; }).runTest {
  name = "systemd-failure-notify";
  nodes.machine = { ... }: {
    imports = [ ../../modules/nixos/services/systemd-failure-notify.nix ];
    services.systemd-failure-notify = { enable = true; services = [ "boom" ]; };
    systemd.services.boom = {
      serviceConfig = { Type = "oneshot"; ExecStart = "${pkgs.coreutils}/bin/false"; };
    };
  };
  testScript = ''
    start_all()
    machine.systemctl("start boom.service", check=False)
    machine.wait_until_succeeds(
      "journalctl -t systemd-failure-notify | grep -q 'Service boom failed'"
    )
  '';
}
```

Register it in `flake/checks.nix` `ciTestsFor` and add a `validate.sh profile-test` case.

### Validate

`bash scripts/validate.sh profile-test profile-systemd-failure-notify` (after wiring), or build the test
attr directly. Confirm the journal assertion sees the real unit name.

---

## FIX P0-2 — Untested alert ruleset (silent metric-name/expr typos)

### Current code

`modules/nixos/profiles/observability/alerts.nix` builds `rulesFile` / `alertmanagerFile` as YAML and
drops them via tmpfiles. No syntax or semantic check.

### Fix (cheap, light-lane)

Add a derivation check that lints the generated YAML with `promtool`/`mimirtool` and `amtool`:

```nix
# flake/checks.nix (new check)
observability-alerts-lint = pkgs.runCommand "observability-alerts-lint"
  { nativeBuildInputs = [ pkgs.prometheus pkgs.alertmanager ]; } ''
    promtool check rules ${rulesFile}      # rulesFile exposed from alerts.nix or rebuilt here
    amtool check-config ${alertmanagerFile}
    touch $out
  '';
```

To get `rulesFile`/`alertmanagerFile` out of `alerts.nix`, either refactor the YAML builders into
`lib/observability-alerts.nix` (importable by both the module and the check) or rebuild the same attrset in
the check. Prefer the lib extraction so module and check cannot drift.

### Fix (stronger, optional)

Add a NixOS test that boots `profiles.observability` with mimir+ruler, pushes synthetic series breaching
e.g. `ResticBackupStale` (`restic_last_backup_timestamp_seconds` set 30h in the past), and asserts the
ruler API reports the alert firing.

### Validate

`promtool check rules <file>` exits non-zero on any bad metric/label/expr. Add the new check attr to
`scripts/validate.sh light` and `flake/checks.nix`.

---

## FIX P0-3 / P1-4 — Planner under-selection can produce a green merge-gate

### Current code

`scripts/test-ci-plan.sh` checks a fixed sample of paths. `scripts/ci-plan.sh:149` has an
`unknown_module_changed` catch-all for `modules/nixos/` but nothing covers `hosts/installer/` and the test
never asserts the catch-all stays wired.

### Issue

`merge-gate` (`.github/workflows/nix.yml:506-516`) trusts the plan: a skipped-but-should-have-run test job
passes the gate. Coverage correctness lives entirely in `ci-plan.sh`.

### Fix

Extend `scripts/test-ci-plan.sh` to enumerate the real tree and fail on any path that selects nothing
beyond eval+lint:

```bash
while IFS= read -r f; do
  out="$(run_plan "$f")"
  if grep -q 'hosts=false' <<<"$out" && grep -q 'tests=false' <<<"$out" \
     && grep -q 'run_packages=false' <<<"$out"; then
    echo "ci-plan selects no build for: $f" >&2; exit 1
  fi
done < <(git ls-files 'modules/nixos/**/*.nix' 'hosts/**/*.nix')
```

Add an explicit `installer` rule in `ci-plan.sh` (build its closure or assert it's intentionally
eval-only).

### Validate

`bash scripts/test-ci-plan.sh` must pass and must fail if you add a new `modules/nixos/foo.nix` that no rule
selects.

---

## FIX P0-4 / P1-1 — No CVE scan in CI; weekly auto-merge has no dependency-CVE guard

### Current state

`scripts/validate.sh cve-reports` and `flake/checks.nix:412-423` build CVE reports; no workflow runs them.
`flake-update.yml` auto-merges on a green `merge-gate` that excludes any CVE signal.

### Fix

Add a job to `.github/workflows/nix.yml` and include it in `merge-gate.needs` (gate it on the planner so it
runs for `flake.lock`/host changes):

```yaml
cve:
  needs: [push-policy, changes]
  if: needs.changes.outputs.hosts == 'true'
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@... # pinned SHA
    - uses: ./.github/actions/setup-nix
    - run: bash scripts/validate.sh cve-reports
```

Then add `cve` to `merge-gate.needs` and a `require_when_planned "cve" "$PLAN_HOSTS" "$RESULT_CVE"` line.
Decide policy: fail on any non-whitelisted CVE (matches the `VulnixCveFound` alert), or warn-only with a PR
comment. If warn-only is chosen, document the residual risk in `docs/security.md` and do NOT auto-merge
lock bumps that add criticals.

### Validate

Run `bash scripts/validate.sh cve-reports` locally; confirm it prints the report and exits non-zero when a
known-vulnerable package is present (test by temporarily lowering the whitelist).

---

## FIX P1-2 — No impermanence/rollback behavioral test

### Fix — `tests/nixos/impermanence-rollback.nix`

Use a minimal config that mirrors the `main` ephemeral-root pattern (or test
`profiles/impermanence-base.nix` directly with a tmpfs `/` overlay). Two-boot test:

```python
machine.start()
machine.succeed("echo ephemeral > /var/lib/should-vanish")
machine.succeed("mkdir -p /persist/keep && echo persisted > /persist/keep/file")
machine.shutdown()
machine.start()
machine.fail("test -f /var/lib/should-vanish")
machine.succeed("grep -q persisted /persist/keep/file")
```

Wire into `flake/checks.nix` + `validate.sh`. If a full rollback-root reproduction is too heavy, at minimum
assert the `environment.persistence."/persist"` bind mounts resolve and the non-persisted path is on a
volatile fs.

### Validate

`bash scripts/validate.sh profile-test impermanence-rollback` (after registering).

---

## FIX P1-3 — No sops decryption test

### Fix

Add a NixOS test that generates an age key in-VM, encrypts a throwaway secret with `sops`, configures
`sops.secrets.test = { sopsFile = ...; }`, and asserts the plaintext appears at `/run/secrets/test` after
boot. This proves the decryption path (not the in-store-file shortcut the smoke test uses). Keep it host-
agnostic so it does not depend on real `.sops.yaml` key groups; a separate eval check can assert each host
key appears in the expected `.sops.yaml` regex group.

### Validate

Build the new test attr; assert `/run/secrets/test` content matches.

---

## FIX P1-5 — Assert kernel sysctls and SSH hardening at runtime

### Fix — extend `tests/nixos/profile-security.nix`

Add to the existing `target` node assertions:

```python
target.succeed("sysctl -n kernel.unprivileged_bpf_disabled | grep -q '^1$'")
target.succeed("sysctl -n net.ipv4.conf.all.accept_redirects | grep -q '^0$'")
target.succeed("sshd -T | grep -qi '^permitrootlogin no$'")
target.succeed("sshd -T | grep -qi '^passwordauthentication no$'")
```

Note the existing test forces `PasswordAuthentication = lib.mkForce true` for the fail2ban scenario; add a
**second node** (or a second sshd config) that keeps the hardened defaults so the assertion is meaningful.

### Validate

`bash scripts/validate.sh profile-test profile-security`.

---

## FIX P1-6 — Assert `main` sudo password policy and allowlist at runtime

### Fix — `tests/nixos/profile-sudo-allowlist.nix`

Import the sudo/allowlist config used by `main` (factor `agentMaintenanceCommands` into a shared module if
not already). As `user`:

```python
# non-allowlisted command must require a password (non-interactive sudo fails)
machine.fail("sudo -n -u root true")
# an allowlisted command runs NOPASSWD
machine.succeed("sudo -n systemctl status btrbk-local.service || true")  # adjust to a real allowlisted cmd
```

Run as the unprivileged user via `machine.succeed("su user -c '...'")`.

### Validate

Build the test; confirm it fails if `wheelNeedsPassword` is flipped to false or the allowlist regex is
widened to `ALL`.

---

## FIX P2-1 — Smoke test should skip (not fail) without KVM

### Current code

`tests/nixos/homeserver-gcp-smoke.nix:163-165`:

```python
assert os.path.exists('/dev/kvm'), \
  "KVM not available: /dev/kvm missing. Smoke tests require KVM acceleration."
```

### Fix

Prefer letting the nixos-test driver handle acceleration (drop the assert) or convert to a skip the CI can
interpret. If the intent is to _require_ KVM in CI, keep the assert but ensure the `tests` job in `nix.yml`
runs on a runner that guarantees `/dev/kvm`; otherwise this is a flaky red gate. At minimum, gate the assert
behind an env var (`SMOKE_REQUIRE_KVM`) so local non-KVM runs skip instead of erroring.

### Validate

Run the smoke test on a non-KVM host and confirm it skips rather than hard-fails.

---

## FIX P2-2 — Decode and assert the actual auth credentials

### Current code

`tests/nixos/profile-observability.nix:108-111` greps for `Authorization: Basic`.

### Fix

```python
obs_auth.wait_until_succeeds("grep -q 'Authorization: Basic' /tmp/stub/last-request", timeout=90)
hdr = obs_auth.succeed("grep -m1 'Authorization: Basic' /tmp/stub/last-request").split()[-1].strip()
import base64
obs_auth.succeed(f"test '{base64.b64decode(hdr).decode()}' = 'telemetry:test-secret'")
```

(The decode must run on the test driver host; use Python in the testScript, which already runs there.)

### Validate

`bash scripts/validate.sh profile-test profile-observability`; confirm it fails if the password file is
changed without updating the assertion.

---

## FIX P2-5 — Unify the three drifting secret-scan patterns

### Current state

Three copies of the token regex:

- `scripts/scan-plaintext-secrets.sh:13`
- `pre-commit-hooks.nix:29` (inline)
- `scripts/check-secrets-directory.sh:74-84` (different set)

### Fix

Create `scripts/lib/secret-patterns.sh` exporting `SECRET_REGEX` (the union of all token shapes) and source
it from both shell scripts. For the pre-commit hook, read the same file at hook build time
(`builtins.readFile ./scripts/lib/secret-patterns.sh` extraction, or have the hook call the script). Add a
test asserting all three entry points reject the same fixture set (extend
`tests/lib/scan-plaintext-secrets.nix` to also exercise `check-secrets-directory.sh` token markers).

### Validate

`nix build .#checks.${system}.lib-scan-plaintext-secrets` and `pre-commit run no-plaintext-secrets
--all-files`.

---

## FIX P2-6 / P2-3 — Generator edge cases

- Add a numeric-attribute case to `tests/lib/generators.nix` `toAlloyHCL`:
  `body = { retries = 3; ratio = 0.5; };` → assert `retries = 3` and `ratio = 0.5` render unquoted.
- For ACL ordering (`tests/lib/acl.nix`), add a case whose `acceptFrom` ports are **descending** in the
  input and assert the rendered `dst` is ascending — this proves the generator sorts rather than passing
  through input order.

### Validate

`nix build .#checks.${system}.lib-generators .#checks.${system}.lib-acl`.

---

## FIX P3-1 / P3-2 — Anonymous-spec & VPN-coexistence invariants (pure eval, cheap)

### Fix — add to `flake/checks.nix`

```nix
anonymousSpecDisablesDeanonServices = {
  name = "anonymous specialisation disables deanonymizing services";
  check = cfg: let s = cfg.specialisation.anonymous.configuration; in
    require (!s.services.tailscale.enable
          && !s.services.openssh.enable
          && !s.profiles.observability.enable
          && s.networking.firewall.checkReversePath == "strict")
      "anonymous spec must disable tailscale/ssh/observability and force strict rpfilter";
};
```

(Adjust attr paths to how the specialisation is exposed; if it is a separate `nixosConfiguration`, build
that config instead.) Add a companion invariant asserting the three Mullvad/Tailscale coexistence
mechanisms exist on the _default_ `main` config and are _absent_ in the anonymous spec.

### Validate

`bash scripts/validate.sh light` (add the new invariants to the `invariants-main` set).

---

## FIX P3-4 / P3-6 — Workflow/YAML linting

Add `actionlint` (validates GitHub workflow syntax + `if:` expressions) as a pre-commit hook and a CI lint
step, and extend `treefmt.nix` with `yamlfmt`/`taplo` for `*.yml`/`*.toml`. This catches malformed gate
expressions in `nix.yml` at commit time instead of at workflow-run time.

### Validate

`nix run nixpkgs#actionlint -- .github/workflows/*.yml` and `pre-commit run --all-files`.
