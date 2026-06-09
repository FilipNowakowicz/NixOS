# Security Audit — NixOS Flake (2026-06-09)

Read-only audit of the implementation against the threat model declared in
`CLAUDE.md` and `docs/security.md`. Every claim below was verified in source;
citations are `file:line` as of branch `fable-security` (HEAD `5050b49`).

**Overall**: the implementation matches the documented model unusually well.
The big, scary properties (sops scoping, initrd-secret assertion, tailnet-only
SSH, narrow agent sudo, exact trusted-users) are not just configured but
_enforced_ by eval-time assertions and merge-gate invariants. The findings
below are mostly edges where enforcement has gaps, where a drift whitelist
papers over a real misbinding, or where a credential artifact sits outside the
sops envelope.

---

## 1. Verified-good baseline (what was checked and held)

| Claim (docs)                                                                   | Verified at                                                                                                                                                                                                                                      | Result                                                                                                                                                                                                                                              |
| :----------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Per-host sops key groups: each host decrypts only its own `hosts/<h>/secrets/` | `.sops.yaml:16-35`                                                                                                                                                                                                                               | ✅ Four rules, each scoped to one host dir + `&user`; `home/users/user/secrets/` is `&user`-only                                                                                                                                                    |
| Registry↔sops parity is enforced                                               | `lib/invariants.nix:80-109`, wired at `flake/checks.nix:584-593`                                                                                                                                                                                 | ✅ Stale/missing host rules or recipient keys fail `merge-gate`                                                                                                                                                                                     |
| `boot.initrd.secrets` must be `/run/secrets/*`                                 | assertion `modules/nixos/profiles/sops-base.nix:2-5,19-24`                                                                                                                                                                                       | ✅ Only two initrd secrets exist: `hosts/main/default.nix:266-268` (mkForce to `/run/secrets/initrd_ssh_host_ed25519_key`) and `hosts/mac/default.nix:102-105` (`/run/secrets/luks_keyfile`); all hosts that define initrd secrets import sops-base |
| No cleartext secret values committed                                           | spot-checked all of `hosts/*/secrets/*.yaml`, `home/users/user/secrets/*`                                                                                                                                                                        | ✅ All values `ENC[AES256_GCM,...]`; `.enc` blobs binary-sops; plaintext scan hook + narrow allowlist (`.plaintext-secrets-allowlist`) exists. One exception → finding C1                                                                           |
| `main` keeps `wheelNeedsPassword = true` + narrow allowlist                    | `hosts/main/default.nix:10-36,191-207`; golden check `flake/checks.nix:59-92,244-249`                                                                                                                                                            | ✅ (allowlist argument-injection audit below; check-coverage gap → C3b)                                                                                                                                                                             |
| Broad passwordless sudo is exactly the documented set                          | grep over all `.nix`: only `hosts/mac/default.nix:116`, `hosts/homeserver-gcp/default.nix:78`, `hosts/gcp-builder/default.nix:25`, `modules/nixos/profiles/machine-dev.nix:10` (consumed only by `microvm-guest.nix:8,15`, amnesic tmpfs guests) | ✅ Plus the _transient_ GCP `bootstrap` user (`infra/main.tf:139-142`, `infra/builder.tf:82-83`) — documented in `docs/security.md:343`                                                                                                             |
| gcp-builder tailnet-only + key-only                                            | `hosts/gcp-builder/default.nix:29-33` (tailscale0 TCP 22 only), `:94-97` (`openFirewall = false`), `:173-178` (key-only, no sops → no console password); GCP edge `infra/main.tf:31-42` blocks public TCP/22 network-wide                        | ✅ live config; enforcement gap → C3a                                                                                                                                                                                                               |
| `main`/`mac` SSH not on public interface                                       | `hosts/main/default.nix:289-291` + `hosts/main/networking.nix:60-67`; `hosts/mac/default.nix:43-47,153-156`; invariants `lib/invariants.nix:403-418,507-520`                                                                                     | ✅                                                                                                                                                                                                                                                  |
| Exact per-host nix trusted-users, no `*`/`@group`                              | `modules/nixos/profiles/nix-trusted-users.nix:26-39` (eval-failing assertions)                                                                                                                                                                   | ✅ `root`+`user` only, on main/mac/homeserver/builder                                                                                                                                                                                               |
| Grafana auth-proxy trusts only 127.0.0.1; local spoofing accepted              | `hosts/homeserver-gcp/grafana.nix:74-82`, accepted in `docs/security.md:247-254`                                                                                                                                                                 | ✅ documented residual risk                                                                                                                                                                                                                         |
| sshd hardening (no root login, no passwords, fail2ban coupled)                 | `modules/nixos/profiles/security.nix:32-58` (assertion ties SSH→hardened fail2ban)                                                                                                                                                               | ✅ installer ISO is the only `prohibit-password` root-key exception (`hosts/installer/default.nix:9-22`) — reasonable for nixos-anywhere                                                                                                            |
| homeserver bootstrap key handling (no key in TF state/metadata)                | `scripts/deploy-gcp.sh:39-56,110-144,155-178` — decrypt to tmpdir w/ exit trap, keyscan-verify, `--extra-files`, metadata removal **verified** post-install                                                                                      | ✅ matches `docs/security.md:26`                                                                                                                                                                                                                    |
| tfstate/tfvars not committed                                                   | `infra/.gitignore` (`*.tfstate*`, `terraform.tfvars`); `git ls-files infra` confirms                                                                                                                                                             | ✅                                                                                                                                                                                                                                                  |

### Open-port inventory (every `allowedTCPPorts`/`allowedUDPPorts`/`openFirewall`)

| Host           | Interface                | Port(s)                                                           | Justification                                                    | Source                                     |
| :------------- | :----------------------- | :---------------------------------------------------------------- | :--------------------------------------------------------------- | :----------------------------------------- |
| main           | tailscale0               | TCP 22, 24800, 47984, 47989, 48010; UDP 47998–48000, 48002, 48010 | SSH; Input Leap; Sunshine for mac companion                      | `hosts/main/networking.nix:60-75`          |
| main           | all (UDP 41641)          | tailscaled via `openFirewall = true`                              | WireGuard endpoint                                               | `hosts/main/networking.nix:114-117`        |
| main           | wired only, stage 1 only | TCP 2222                                                          | initrd LUKS recovery; torn down by `flush-network-before-stage2` | `hosts/main/default.nix:234-268`           |
| mac            | tailscale0               | TCP 22, 22000; UDP 22000, 21027                                   | SSH; Syncthing                                                   | `hosts/mac/default.nix:43-52`              |
| mac            | all (UDP 41641)          | tailscaled                                                        | WireGuard endpoint                                               | `hosts/mac/default.nix:164-167`            |
| homeserver-gcp | tailscale0               | TCP 22, 443                                                       | SSH; nginx HTTPS                                                 | `hosts/homeserver-gcp/default.nix:107-113` |
| homeserver-gcp | tailscale0               | TCP 53, 3001; UDP 53                                              | AdGuard DNS + web UI                                             | `hosts/homeserver-gcp/adguard.nix:86-93`   |
| homeserver-gcp | all (UDP 41641)          | tailscaled                                                        | WireGuard endpoint                                               | `hosts/homeserver-gcp/default.nix:195-199` |
| gcp-builder    | tailscale0               | TCP 22                                                            | SSH / distributed builds                                         | `hosts/gcp-builder/default.nix:29-33`      |
| gcp-builder    | all (UDP 41641)          | tailscaled                                                        | WireGuard endpoint                                               | `hosts/gcp-builder/default.nix:108-113`    |
| installer ISO  | **all**                  | TCP 22                                                            | nixos-anywhere bootstrap; key-only `prohibit-password` root      | `hosts/installer/default.nix:9-22`         |

GCP edge: UDP 41641 allowed from `0.0.0.0/0` per instance tag (`infra/main.tf:9-21`,
`infra/builder.tf:22-34`); network-wide deny of public TCP/22 at priority 500
(`infra/main.tf:31-42`).

---

## 2. Confirmed issues

### C1 — MEDIUM: AdGuard admin bcrypt hash committed in git and baked into the world-readable Nix store

`hosts/homeserver-gcp/adguard.nix:77-82`

```nix
users = [ { name = "admin"; password = "$2y$12$zECsUKzXoQAf4JfIhAg8Kez/..."; } ];
```

Why it matters here: the repo's stated model is "secrets are managed by
sops-nix" with intentional plaintext exceptions recorded as _narrow entries in
`.plaintext-secrets-allowlist`_ (`docs/security.md:29`). This hash is neither —
it lives in a tracked `.nix` file (the inline comment at `adguard.nix:76` calls
it intentional, but it is not in the allowlist at `.plaintext-secrets-allowlist`,
which only lists the smoke-test fixture and two runbooks). Because
`mutableSettings = false` renders the settings into a store path, the hash is
also world-readable on the host. The repo is maintained for public adoption
(README/`public-adoption` work, public `github.com/FilipNowakowicz/nixos-config`
runner URL at `hosts/homeserver-gcp/github-runner.nix:10`), so this is an
offline-crackable credential published to the internet, protecting a UI that
every tailnet device can reach on `tailscale0:3001`.

Fix: deliver the AdGuard `users` block at runtime from a sops secret (e.g.
render the password via a `sops.templates` file consumed by an
`ExecStartPre`/activation step, or use AdGuard's env-substitution), or — if the
risk is genuinely accepted — rotate to a high-entropy password and add a narrow,
justified entry to `.plaintext-secrets-allowlist` so the exception is governed
like the others. Rotating the current password is warranted either way since the
hash is already public.

### C2 — LOW (defense-in-depth, but codified): Loki/Tempo/Mimir gRPC listeners bind all interfaces, and the drift check whitelists the leak

- Loki: `modules/nixos/profiles/observability/backends.nix:23-27` sets
  `http_listen_address = "127.0.0.1"` but only `grpc_listen_port = 9096` —
  `grpc_listen_address` is unset, which in dskit-based servers defaults to all
  interfaces.
- Tempo: same pattern, `backends.nix:60-64` (`grpc_listen_port = 3201`).
- Mimir: `backends.nix:86-89` sets only the HTTP address; the gRPC server
  defaults to `0.0.0.0:9095`.
- The host drift inventory then _expects_ these as non-loopback listeners:
  `expectedExtraTCPPorts = [ 80 3201 9095 9096 22000 ]` at
  `hosts/homeserver-gcp/default.nix:23-29`, consumed by
  `scripts/check-host-drift.sh:69,228` ("unexpected non-loopback listening TCP
  ports").

Why it matters: the documented intent is that the LGTM stack is
localhost-only behind nginx basic-auth ingest (`docs/security.md:217-220`).
These three unauthenticated gRPC endpoints (Loki/Mimir gRPC accept queries and
writes, `auth_enabled = false` at `backends.nix:22`) are currently saved only by
the nftables interface allowlist — they are not reachable over `tailscale0`
(only 22/443/53/3001 are open) or the GCP edge. But the drift check, which
exists to catch exactly this class of exposure, has been taught to call the
misbinding "expected", so the firewall is now a single layer with no detection
behind it.

Fix: set `server.grpc_listen_address = "127.0.0.1"` for Loki, Tempo, and Mimir
in `backends.nix`, then shrink `expectedExtraTCPPorts` to `[ 80 22000 ]`
(nginx's `forceSSL` port-80 redirect listener and user-session Syncthing,
`home/users/user/server.nix:5` — both firewall-blocked and genuinely expected).
The drift check then regains its meaning.

### C3 — MEDIUM: the enforcement layer has two coverage holes

**(a) `gcp-builder` has zero invariant coverage.** `flake/checks.nix:596-632`
builds invariant checks for `main`, `main-ci`, `homeserver-gcp`, and `mac` —
there is no `invariants-gcp-builder`, and `deployTargetAccessAssertions`
(`lib/invariants.nix:467-487`) plus the SSH-tailnet-only checks are never
applied to it. Yet the builder is the host the docs flag as "effective root via
remote builds; keep it tailnet-only and key-only" (`CLAUDE.md` Security
Preferences). Today the config is correct
(`hosts/gcp-builder/default.nix:29-33,94-97`), but a one-line regression
(`services.openssh.openFirewall = true`, or a password user) would sail through
`merge-gate` while the same change on mac/homeserver would fail.
Fix: add an `invariants-gcp-builder` entry reusing `macSshNotGloballyOpen`/
`macSshTailscaleOnly`-style checks plus "no password users / key-only" and
"firewall enabled" assertions. (Note `sops.age.sshKeyPaths` check from
`deployTargetAccessAssertions` doesn't apply since `sops = false` in
`lib/hosts.nix:93` — split that list rather than skipping it wholesale.)

**(b) The "narrow sudo allowlist" golden check only inspects rules whose
`users == [ "user" ]`.** `flake/checks.nix:81-83`:

```nix
userRules = lib.filter (rule: rule.users or [ ] == [ "user" ]) (cfg.security.sudo.extraRules or [ ]);
```

A future `extraRules` entry keyed on `groups = [ "wheel" ]`, on a different
username, or on `users = [ "user" "other" ]` would be invisible to this check,
and the companion "no passwordless sudo" check (`flake/checks.nix:244-249`)
only reads the `wheelNeedsPassword` boolean. So a broad
`{ groups = ["wheel"]; commands = [{ command = "ALL"; options = ["NOPASSWD"]; }]; }`
on `main` would pass every invariant while violating the core documented
guarantee. Fix: assert that the _complete_ `security.sudo.extraRules` list on
`main` equals the expected structure (after filtering, assert the residue is
empty), not just that the user-scoped subset matches.

### C4 — LOW: reusable, pre-approved Tailscale auth key persists indefinitely on the builder's unencrypted disk

`hosts/gcp-builder/default.nix:104-113` — `authKeyFile = "/var/lib/tailscale-authkey"`,
deliberately minted **reusable**, non-ephemeral, pre-tagged `tag:server`
(provisioning runbook, `hosts/gcp-builder/CLAUDE.md`). After first join the file
is no longer needed ("the key is used once"), but nothing deletes it; the
NixOS tailscale module does not consume-and-remove `authKeyFile`. The GCE disk
is not LUKS-encrypted at the guest layer, so anyone with GCP project access can
snapshot the disk and mint a `tag:server` tailnet node — which the ACL then
trusts. (GCP project access is already root on these VMs, so this is an
_escalation persistence_ issue, not a new principal — hence LOW.)
Fix: a oneshot unit that shreds `/var/lib/tailscale-authkey` once
`tailscale status` reports a node identity (or set
`services.tailscale.extraUpFlags`/key with a short expiry and re-mint on
reprovision). Also consider a key with expiry: reusable + non-expiring +
pre-approved is the most powerful combination Tailscale offers.

### C5 — LOW: `.sops.yaml` path regexes are unanchored

`.sops.yaml:17,21,26,31` — sops matches `path_regex` as a search, so
`hosts/main/secrets/.*` also matches e.g.
`examples/anything/hosts/main/secrets/foo.yaml`. With the current tree this is
purely theoretical (the parity check at `lib/invariants.nix:58-78` even parses
these regexes), but an `examples/` or test fixture placed under a colliding
sub-path would silently be encrypted to a _real host key_.
Fix: anchor each rule (`^hosts/main/secrets/.*`), matching sops' documented
recommendation.

### C6 — LOW: tag reuse widens the generated ACL beyond either host's need

`lib/hosts.nix:69` (homeserver) and `:89` (gcp-builder) both carry
`tailscale.tag = "server"`, and the ACL generator emits tag-to-tag rules
(`lib/acl.nix:83-97`). The union of `acceptFrom` therefore grants
`tag:workstation → tag:server:22,443,53,3001` — i.e. workstations may reach
**gcp-builder** on 443/53/3001 at the ACL layer even though the builder only
intends port 22 (`lib/hosts.nix:90`). Today the builder's in-guest firewall
(`hosts/gcp-builder/default.nix:31`) blocks the extra ports and nothing listens,
but the ACL no longer encodes the per-host intent the registry expresses.
Fix: give the builder its own tag (e.g. `tag:builder`) so the generated rules
stay per-role; the runbook note about "no ACL change needed" trades exactly this
precision for convenience — worth reversing now that the generator makes new
tags cheap.

### C7 — LOW: identity data hardcoded outside the host registry

The registry is documented as the single source of truth for tailnet identity
(`CLAUDE.md`, `lib/hosts.nix:1-21`), and FQDN consumers do flow through it
(`hosts/main/default.nix:91`, `hosts/homeserver-gcp/default.nix:10`,
`hosts/main/nix-remote-build.nix:15`). Two divergences:

- `hosts/homeserver-gcp/adguard.nix:45-72` hardcodes five tailnet **IPs**
  (`100.111.88.61`, `100.73.117.103`, `100.103.234.89`, plus two phones) that
  appear nowhere in `lib/hosts.nix`. If a node is re-keyed/re-added and gets a
  new CGNAT address, the per-client AdGuard policy silently misattributes
  traffic. Fix: add tailnet IPs (or MagicDNS names — AdGuard accepts client IDs
  by name) to the registry and derive this block.
- `flake/deploy.nix:23` sets `hostname = name` (bare registry key), relying on
  MagicDNS search-domain resolution instead of `tailnetFQDN`. Functional, but a
  second divergence from the "FQDN comes from the registry" rule and brittle if
  the operator's resolver lacks the tailnet search domain. Fix: use
  `hostRegistry.<name>.tailnetFQDN`.

---

## 3. Sudo allowlist audit (item-by-item)

`hosts/main/default.nix:10-32`, mirrored by the golden list at
`flake/checks.nix:59-74`. sudoers argument matching reviewed for each entry:

| Entry                                                       | Verdict                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| :---------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `systemctl start/status …` ×9 (`:12-20`)                    | ✅ Exact argv; unit names fixed; no wildcards                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `bootctl status --no-pager`, `bootctl cleanup` (`:23-24`)   | ✅ Exact argv                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `efibootmgr -b [0-9A-F][0-9A-F][0-9A-F][0-9A-F] -B` (`:25`) | ✅ Safe: each fnmatch bracket class matches exactly one character and cannot match a space, so the classic sudoers `*`-spans-arguments escape does not apply; argv is forced to exactly `-b XXXX -B`                                                                                                                                                                                                                                                                                                                                                                 |
| `nix-gc-14d` (`:26`, wrapper `:43-45`)                      | ✅ No-args command spec means sudo permits _any_ argv, but the wrapper `exec`s a fixed `nix-collect-garbage --delete-older-than 14d` and never references `$@`                                                                                                                                                                                                                                                                                                                                                                                                       |
| `nixos-switch-main` (`:31`, wrapper `:39-41`)               | ⚠️ Same any-argv note (ignored by wrapper). **Root-equivalent by design**: it activates from user-writable `/home/user/nix`. This is explicitly documented and accepted (`docs/security.md:326-329`, `hosts/main/CLAUDE.md`), so not a finding — but note that because of it (plus `user` being a Nix trusted-user, `hosts/main/default.nix:87`), the `user` account on `main` is effectively root, and `wheelNeedsPassword = true` is a guard against _drive-by mistakes_, not against a compromised user session. The docs say as much; keep treating it that way. |

All entries resolve under root-controlled `/run/current-system/sw/bin`, not
user-writable paths. ✅

---

## 4. Worth a closer look

### W1 — The R2 binary-cache trust edge is undocumented in the threat model

`hosts/main/default.nix:100-106` and `hosts/mac/default.nix:122-127` trust
`nix-cache-1:eEcFiWPHQpJmlcnNeGoPg6xxOp3itNZiWwFaE+NebIk=` for an R2-hosted
substituter, and `hosts/homeserver-gcp/default.nix:81-84` /
`hosts/gcp-builder/default.nix:60-63` trust `main.local:…`. Whoever holds the
CI signing private key (presumably a GitHub Actions secret used by
`scripts/push-to-r2.sh`) can serve substitutable store paths to both
workstations. That is a real "GitHub repo admin → code on `main`" edge,
parallel to the (well-documented) runner root-equivalence on homeserver-gcp —
but `docs/security.md` never mentions the cache or the signing-key custody/
rotation story. Suggest: document key custody, and scope the substituter to CI
builds if feasible.

### W2 — GCP `default` VPC keeps `default-allow-internal`

Both instances sit on `network = "default"` (`infra/main.tf:93`,
`infra/builder.tf:57`) with only TCP/22 denied network-wide
(`infra/main.tf:31-42`). The auto-created `default-allow-internal` rule permits
all traffic between instances on `10.128.0.0/9`, so the builder and homeserver
are mutually reachable on **all ports** at the cloud layer; the in-guest
nftables interface allowlist is the only boundary (and per C2, three
unauthenticated gRPC listeners sit right behind it on non-loopback binds).
Suggest: a dedicated VPC without the default-allow rules, or an explicit deny
mirroring `deny_public_ssh` for inter-instance traffic — at minimum after C2 is
fixed this is belt-and-braces.

### W3 — Builder provisioning never removes bootstrap metadata

`scripts/deploy-gcp.sh:155-178` removes and verifies removal of
`bootstrap-ssh-public-key`/`startup-script` for the homeserver, but the
builder runbook (`hosts/gcp-builder/CLAUDE.md`, step 6) only shreds the staged
tailscale key and deletes the temp firewall rule. The metadata startup script
(`infra/builder.tf:66-87`) recreates a `NOPASSWD:ALL` bootstrap user — inert on
NixOS (no GCE guest agent in `hosts/gcp-builder/hardware-configuration.nix`),
but it re-arms automatically if the disk is ever re-imaged from a stock image.
Suggest: add the same `remove-metadata` step to the builder runbook.

### W4 — Documented-and-accepted residual risks (re-verified, no action needed, listed for completeness)

- **mac LUKS keyfile in the initrd on the unencrypted ESP** —
  `hosts/mac/default.nix:92-106`; accepted with an explicit revert-before-travel
  procedure (`hosts/mac/CLAUDE.md`). The keyfile passes through
  `/run/secrets/luks_keyfile`, satisfying the initrd assertion.
- **GitHub runner = root on homeserver-gcp for anyone who can merge to `main`**,
  and the registration PAT is repo-Administration scoped —
  `hosts/homeserver-gcp/github-runner.nix:7-34`; thoroughly documented with
  rotation procedure (`hosts/homeserver-gcp/CLAUDE.md`,
  `docs/security.md:136-157`). The runner also re-authorizes a self-deploy SSH
  key (`github-runner.nix:46-48`) whose private half is sops-managed
  (`default.nix:292-297`). Consistent.
- **Grafana auth-proxy spoofable from localhost** — `grafana.nix:74-82`,
  accepted at `docs/security.md:247-254`; holds only while no untrusted local
  users/services exist on the host (same caveat covers Vaultwarden on
  `127.0.0.1:8222`, `default.nix:241-251`).
- **`autogroup:admin` `*:*` break-glass** in the generated ACL —
  `lib/acl.nix:110-117`, accepted at `docs/security.md:236-241`. Note this is
  also how the untagged phone clients in `adguard.nix:63-71` reach DNS/Vaultwarden
  at all — worth one sentence in the docs, since removing the break-glass rule
  would silently cut the phones off.
- **`checkReversePath = "loose"`** on main/mac/homeserver/builder
  (`hosts/main/networking.nix:59`, `hosts/mac/default.nix:57`,
  `hosts/homeserver-gcp/default.nix:108`, `hosts/gcp-builder/default.nix:30`)
  — required by the dual-VPN/asymmetric routing model; documented; the anonymous
  specialisation forces it back to `strict` and an invariant pins the whole
  coexistence contract (`lib/invariants.nix:206-279`).
- **mac Wi-Fi MAC randomization disabled** (`hosts/mac/default.nix:39-41`) —
  driver-forced (`wl`/wext); a tracking/privacy tradeoff, not in the threat
  model's scope, but unlike the other exceptions it carries no inline rationale
  tying it to the Broadcom limitation. One comment line would do.

---

## 5. Top 3 things to fix first

1. **C2 — pin the LGTM gRPC listeners to loopback** (`backends.nix`: add
   `grpc_listen_address = "127.0.0.1"` ×3) **and shrink
   `expectedExtraTCPPorts` to `[ 80 22000 ]`** so the drift check detects
   non-loopback listeners again. Smallest diff, removes the only
   unauthenticated network services on the most exposed host, and restores a
   detection layer.
2. **C3 — close the enforcement holes**: add `invariants-gcp-builder` to
   `flake/checks.nix`, and make the `main` sudo golden check assert over the
   _entire_ `security.sudo.extraRules` list instead of the
   `users == ["user"]` subset. These convert two currently-true-by-luck
   properties of the documented threat model into merge-gate-enforced ones.
3. **C1 — get the AdGuard admin hash out of git/store** (sops-templated users
   block, or allowlist + rotate to high-entropy). It is the only secret-class
   artifact that escapes the otherwise-tight sops envelope, and the repo's
   public-adoption posture makes it permanently published.
