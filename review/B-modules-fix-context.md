# Fix Context — `modules/nixos/` Review B

Self-contained prompts for a fix agent. Each item has the offending excerpt, the
exact issue, a concrete fix, and a validation command. Validate only what you
change (see CLAUDE.md). Fast gate is
`bash scripts/validate.sh flake-eval`; host closures via
`bash scripts/validate.sh host <name>`; profile tests via
`bash scripts/validate.sh profile-tests`.

## Current Status

- `[DONE]` P0-1, P1-2, P1-3, P1-4, P1-5, and P1-6 landed.
- `[DONE]` P0-2 landed as an optional webhook receiver and `homeserver-gcp`
  wires it to the sops-backed `alertmanager_webhook_url` secret.
- `[DONE]` P2-3/P2-4 now rejects empty Restic backup path lists and
  `homeserver-gcp` runs a restore canary with a freshness metric.
- `[OPEN]` P0-3, P1-1, P2-2, P2-5, P2-1/P3-2, and P3-5
  remain open.

---

## FIX P0-1 — hardened baseline silently overridden by nixpkgs

File: `modules/nixos/services/hardened.nix:99-117`

```nix
systemd.services = lib.mkMerge (
  lib.mapAttrsToList (
    name: serviceCfg:
    lib.mkIf serviceCfg.enable {
      ${name}.serviceConfig =
        let
          skippedKeys = serviceCfg.relaxBase ++ lib.attrNames serviceCfg.extraConfig;
          # Base options not touched by extraConfig: apply at mkDefault so nixpkgs modules win.
          passiveBase = lib.filterAttrs (k: _: !(lib.elem k skippedKeys)) baseHardening;
          activeExtra = serviceCfg.extraConfig;
        in
        lib.mkMerge [
          (lib.mapAttrs (_: lib.mkDefault) passiveBase)
          activeExtra
        ];
    }
  ) cfg
);
```

Issue: baseline hardening is applied at `mkDefault`, so for any key the upstream
nixpkgs unit already defines (nginx, vaultwarden set several), the baseline value
is discarded with no signal. The module advertises a strict baseline that, in
practice, is partially or fully a no-op for those units.

Suggested fix (choose one; preferred = A):

A. Apply the baseline at normal priority so it wins unless the host opts out via
`relaxBase`. The escape hatch already exists (`relaxBase`), so this restores the
"hardening wins by default" semantic the module name implies:

```nix
        in
        lib.mkMerge [
          # Hardening baseline wins over nixpkgs defaults; per-service opt-out is
          # via relaxBase, override-with-value is via extraConfig.
          passiveBase
          activeExtra
        ];
```

(Drop the `lib.mapAttrs (_: lib.mkDefault)` wrapper.) Audit each currently
hardened unit (thermald, power-profiles-daemon, fwupd, bluetooth on main; nginx,
vaultwarden on gcp) after the change — the existing `relaxBase` lists were tuned
against `mkDefault` semantics and may now need additional `relaxBase` entries
where the upstream value was intentionally relied on.

B. If A is too invasive, keep `mkDefault` but add a build-time warning when a
baseline key is shadowed. This is harder (needs to read the final merged value)
and is best done via a profile test (see FIX P3-5) rather than in-module.

Validation:

```
bash scripts/validate.sh host homeserver-gcp
bash scripts/validate.sh host main-ci   # or: bash scripts/validate.sh flake-eval
# Then on a booted gcp test VM (or smoke test): systemd-analyze security nginx.service
```

---

## FIX P0-2 — alerts route to a null receiver

File: `modules/nixos/profiles/observability/alerts.nix:127-142`

```nix
alertmanagerFile = mkYaml "alertmanager.yaml" {
  route = {
    receiver = "null";
    ...
  };
  receivers = [ { name = "null"; } ];
};
```

Issue: every alert terminates in a null receiver — no operator notification.

Suggested fix: add a configurable receiver block with a sops-backed secret. Add
options under `profiles.observability.alerting`:

```nix
options.profiles.observability.alerting = {
  receiver = lib.mkOption {
    type = with lib.types; nullOr (enum [ "email" "webhook" ]);
    default = null;
    description = "Notification channel for fired alerts. null keeps the null receiver.";
  };
  webhookURLFile = lib.mkOption {
    type = with lib.types; nullOr path;
    default = null;
    description = "File containing the webhook URL (e.g. ntfy/Pushover) for alert delivery.";
  };
  # ...email fields as needed...
};
```

Then build the alertmanager `receivers`/`route` from these, defaulting to the
existing null behavior so current hosts are unaffected until they opt in. A
minimal webhook receiver (ntfy) is the lowest-friction option. Wire the secret on
homeserver-gcp via `config.sops.secrets`.

Note: Mimir's alertmanager reads its config via the `C+` tmpfiles copy at
`/var/lib/mimir/alertmanager/anonymous/alertmanager.yaml`; secrets referenced by
file must be readable by `mimir`.

Validation:

```
bash scripts/validate.sh host homeserver-gcp
bash scripts/validate.sh flake-eval
```

---

## FIX P0-3 — metrics enabled with no destination is silent data loss

File: `modules/nixos/profiles/observability/collectors.nix:425-443` (assertions block)

Issue: `metrics.enable = true` with `remoteWriteURL = null` and `mimir.enable =
false` scrapes into a 24h-retention local Prometheus and ships nothing — no
warning.

Suggested fix: add to the existing `assertions` list:

```nix
{
  assertion =
    !cfg.collectors.metrics.enable
    || cfg.collectors.metrics.remoteWriteURL != null
    || cfg.mimir.enable;
  message = ''
    profiles.observability.collectors.metrics.enable has no destination:
    set collectors.metrics.remoteWriteURL or enable mimir, otherwise metrics
    are scraped locally with 24h retention and never shipped.
  '';
}
```

Validation:

```
bash scripts/validate.sh flake-eval
bash scripts/validate.sh host main-ci
```

---

## FIX P1-1 — failure-notify dead on headless / system-service context

File: `modules/nixos/services/systemd-failure-notify.nix:18-22`

```bash
if [[ -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
  export PATH="${pkgs.libnotify}/bin:$PATH"
  notify-send -a "systemd" -u critical "Service Failed" "$SERVICE_NAME failed at $TIMESTAMP" 2>/dev/null || true
fi
```

Issue: the notify-failure unit is a _system_ service; `$WAYLAND_DISPLAY` is not in
its environment, so the toast path never runs. On gcp there is no display at all.
Failures only produce a journal line nobody watches.

Suggested fix: route failures to the same notification channel as FIX P0-2 (a
webhook), independent of any display. Keep the journal line. If a desktop toast is
still wanted, run it as a `systemd.user.services` template attached via the
session bus, not a system unit. Minimal robust version: replace the desktop branch
with a `curl` to the alerting webhook (with a short timeout and `|| true` so a
down channel does not mask the original failure), guarded on the URL being set.

Validation:

```
bash scripts/validate.sh host main-ci
bash scripts/validate.sh host homeserver-gcp
```

---

## FIX P1-2 — machine-dev sudo is import-gated only

File: `modules/nixos/profiles/machine-dev.nix:1-9`

```nix
_: {
  security.sudo.wheelNeedsPassword = false;
  services.openssh.openFirewall = true;
  profiles.nix.extraTrustedUsers = [ "user" ];
}
```

Issue: dangerous settings are unconditional; only a comment keeps them off
non-dev hosts. `microvm-guest.nix` imports this transitively.

Suggested fix: make the dev posture an explicit option, default off:

```nix
{ config, lib, ... }:
{
  options.profiles.machineDev.enable =
    lib.mkEnableOption "disposable/dev-only host posture (broad passwordless sudo, open SSH, trusted user)";

  config = lib.mkIf config.profiles.machineDev.enable {
    security.sudo.wheelNeedsPassword = false;
    services.openssh.openFirewall = true;
    profiles.nix.extraTrustedUsers = [ "user" ];
  };
}
```

Then set `profiles.machineDev.enable = true;` where the disposable posture is
actually wanted (and decide explicitly whether microvm guests want it). Update
`microvm-guest.nix` accordingly.

Validation:

```
bash scripts/validate.sh flake-eval
bash scripts/validate.sh light   # exercises deploy checks / invariants
```

---

## FIX P1-3 — extend kernel hardening sysctls in security.nix

File: `modules/nixos/profiles/security.nix:60-69`

Add host-safe sysctls (keep rp_filter out — main/mac/gcp use loose checkReversePath):

```nix
boot.kernel.sysctl = {
  # existing entries...
  "kernel.kptr_restrict" = lib.mkDefault 2;
  "kernel.dmesg_restrict" = 1;
  "kernel.yama.ptrace_scope" = lib.mkDefault 1;
  "net.core.bpf_jit_harden" = 2;
  "kernel.kexec_load_disabled" = 1;
  # perf_event_paranoid: thermald on main needs perf; it relaxes per-service, so
  # tightening here is safe as long as that service keeps perf_event_open.
  "kernel.perf_event_paranoid" = lib.mkDefault 3;
};
```

Do NOT add `kernel.unprivileged_userns_clone = 0` or
`security.allowUserNamespaces = false` without testing: it breaks Chromium
sandbox, bubblewrap, nix sandboxed builds. Leave that as a documented P3 decision.

Optionally blacklist unused net protocols (Lynis/CIS items):

```nix
boot.blacklistedKernelModules = [ "dccp" "sctp" "rds" "tipc" ];
```

Verify none are needed (sctp can matter for some VPN/SIP setups — none here).

Use `lib.mkDefault` on entries a host might need to override.

Validation:

```
bash scripts/validate.sh flake-eval
bash scripts/validate.sh hosts        # all three import security.nix
```

---

## FIX P1-4 — block broad trusted-users instead of warning

File: `modules/nixos/profiles/nix-trusted-users.nix:27-36`

```nix
assertions = [
  {
    assertion = trustedUserViolations == [ ];
    message = "...";
  }
];
warnings =
  lib.optional (broadTrustedUsers != [ ])
    "nix.settings.trusted-users contains broad trust entries (...); prefer exact users unless this is intentional.";
```

Issue: `*`/`@group` trust is root-equivalent but only warned about.

Suggested fix: add a second assertion (keep the warning removed or as belt-and-
suspenders). Optionally add an `allowBroadTrustedUsers` escape hatch option
defaulting false:

```nix
assertions = [
  { assertion = trustedUserViolations == [ ]; message = "..."; }
  {
    assertion = broadTrustedUsers == [ ];
    message = "nix.settings.trusted-users must not contain broad entries (${lib.concatStringsSep ", " broadTrustedUsers}); broad trust is root-equivalent.";
  }
];
```

Validation:

```
bash scripts/validate.sh flake-eval
bash scripts/validate.sh light
```

---

## FIX P1-5 — fragile btrfs parsing in rollback-root

File: `modules/nixos/profiles/impermanence-base.nix:61-67`

```bash
delete_subvolume_recursively() {
  IFS=$'\n'
  for i in $(btrfs subvolume list -o "$1" | cut -f 9 -d ' '); do
    delete_subvolume_recursively "/btrfs_tmp/$i"
  done
  btrfs subvolume delete "$1"
}
```

Issue: `cut -f 9 -d ' '` assumes a fixed column layout for `btrfs subvolume list`
output, which is not stable across btrfs-progs versions. The path is the last
field.

Suggested fix:

```bash
delete_subvolume_recursively() {
  IFS=$'\n'
  for i in $(btrfs subvolume list -o "$1" | awk '{print $NF}'); do
    delete_subvolume_recursively "/btrfs_tmp/$i"
  done
  btrfs subvolume delete "$1"
}
```

This is initrd code with no test. If feasible, add a profile/VM test that boots
`main`-like config with `rollbackRoot.enable`, seeds `old_roots`, and asserts the
rollback + 30-day prune. Treat the parsing change as the minimum.

Validation:

```
bash scripts/validate.sh host main-ci
# Booted check (manual): journalctl -b -u rollback-root.service
```

---

## FIX P1-6 — provisioned dashboards are editable and deletable

File: `modules/nixos/profiles/observability/default.nix:118-131`

```nix
providers = [
  {
    name = "default";
    orgId = 1;
    folder = "Overview";
    type = "file";
    disableDeletion = false;
    editable = true;
    options.path = "/etc/grafana-dashboards";
  }
];
```

Issue: file-provisioned (code) dashboards marked editable/deletable; UI edits are
silently lost on reload.

Suggested fix:

```nix
    disableDeletion = true;
    editable = false;
```

Validation:

```
bash scripts/validate.sh host homeserver-gcp
```

---

## FIX P2-2 — assert Grafana credentials present when enabled

File: `modules/nixos/profiles/observability/default.nix` (config assertions — add one)

Issue: `grafana.enable` with `adminPasswordFile == null` boots admin/admin with an
ephemeral secret key.

Suggested fix: add an assertion (in `default.nix`'s `config`, since the file
currently has no `assertions` — add one):

```nix
assertions = lib.optionals cfg.grafana.enable [
  {
    assertion = cfg.grafana.adminPasswordFile != null;
    message = "profiles.observability.grafana.enable requires grafana.adminPasswordFile (else Grafana boots with admin/admin).";
  }
  {
    assertion = cfg.grafana.secretKeyFile != null;
    message = "profiles.observability.grafana.enable requires grafana.secretKeyFile (else sessions reset on every restart).";
  }
];
```

Validation:

```
bash scripts/validate.sh flake-eval
bash scripts/validate.sh host homeserver-gcp
```

---

## FIX P2-3 / P2-4 — backup completeness + restore canary

Files: `modules/nixos/profiles/backup.nix`, `lib/invariants.nix:20-29`,
host `backups.nix`.

Issue: a restic job with empty `paths` initializes a repo, backs up nothing, yet
`ExecStartPost` stamps `restic_last_backup_timestamp_seconds`, so
`ResticBackupStale` stays green — a silent empty backup. `restic check` never
tests restore.

Suggested fixes:

1. Extend `hasResticBackup` (or add a new registry assertion) to require
   `backup.paths != []`:
   ```nix
   (backup ? paths && backup.paths != [ ])
   ```
   AND a repo. Wire into `mkRegistryAssertions` under the `backup` branch.
2. Add a restore-canary oneshot per backup host: restore a small known path to a
   tmpdir, verify a sentinel, export
   `restic_last_restore_success_timestamp_seconds`, and add a matching alert in
   `alerts.nix`. Gate metric emission on restore success, not service success.

Validation:

```
bash scripts/validate.sh light        # invariants
bash scripts/validate.sh host homeserver-gcp
```

---

## FIX P2-5 — explicit xdg portal routing

File: `modules/nixos/profiles/desktop.nix:49-56`

```nix
xdg.portal = {
  enable = true;
  extraPortals = with pkgs; [ xdg-desktop-portal-hyprland xdg-desktop-portal-gtk ];
  config.common.default = "*";
};
```

Suggested fix (explicit, matches Hyprland guidance):

```nix
  config = {
    common.default = [ "gtk" ];
    hyprland.default = [ "hyprland" "gtk" ];
  };
```

Validation:

```
bash scripts/validate.sh host main-ci
# Manual: screenshot/screenshare + file picker after deploy.
```

---

## FIX P2-1 / P3-2 — single source for textfile dir and LGTM ports

Files: `base.nix:17,33`, `collectors.nix:470,564-566`, plus port literals across
`default.nix`/`backends.nix`/`collectors.nix`.

Issue: `/var/lib/node-exporter-textfiles` and the LGTM localhost ports are
repeated string literals; drift silently breaks metrics.

Suggested fix: introduce a small shared `let`/options binding (e.g.
`profiles.observability.internal.textfileDir` read-only option, or a `lib`
constants file) and reference it everywhere. Low risk, mechanical.

Validation:

```
bash scripts/validate.sh flake-eval
bash scripts/validate.sh hosts
```

---

## FIX P3-5 — systemd-analyze security profile test (covers P0-1)

Add a NixOS VM test under the profile-tests target that builds homeserver-gcp's
nginx/vaultwarden units and asserts `systemd-analyze security <unit>` exposure is
below a chosen threshold, failing if a baseline hardening key is shadowed.

Validation:

```
bash scripts/validate.sh profile-tests
```
