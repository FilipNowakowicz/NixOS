High: homeserver SSH is globally open and escalates to root without a password.
Attack surface: importing modules/nixos/profiles/machine-common.nix:1 makes homeserver
enable SSH, open port 22, disable sudo passwords, and trust user for Nix builds.
homeserver imports it in hosts/homeserver/default.nix:23. Final eval shows
allowedTCP=[22,443], sudo=false, trusted-users=["root","root","user"].
Enforcement: insecure state is enforced; production-safe sudo/SSH posture is not.
Small hardening: split machine-common into dev-VM and production-machine profiles; for
homeserver, set security.sudo.wheelNeedsPassword = true, remove user from
nix.settings.trusted-users, and restrict SSH to tailscale0 or close it entirely except
break-glass. 2. High: homeserver HTTPS is exposed on every interface, not just Tailscale.
Attack surface: nginx proxies Vaultwarden and observability ingest under the tailnet
FQDN in hosts/homeserver/default.nix:189, but hosts/homeserver/default.nix:231 globally
opens TCP 443. A LAN or routed exposure can reach the password-manager reverse proxy;
the Tailscale cert/FQDN is not a network boundary.
Enforcement: Tailscale enablement is enforced, tailnet-only exposure is only assumed.
Small hardening: replace global networking.firewall.allowedTCPPorts = [ 443 ]; with
networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 443 ];; optionally bind
nginx to the Tailscale IP/interface. 3. Medium: homeserver secrets are decryptable by main, expanding blast radius across hosts.
Attack surface: .sops.yaml encrypts hosts/homeserver/secrets/* to both *main*host and
*homeserver*host in .sops.yaml:34. Those secrets include user_password,
tailscale_auth_key, Grafana secrets, ingest htpasswd, and restic password in hosts/
homeserver/default.nix:235. A compromised main root plus repo checkout can decrypt
server secrets.
Enforcement: broad trust is enforced by SOPS recipients.
Small hardening: remove *main*host from the homeserver rule after bootstrap, rotate
affected secrets, and keep bootstrap decryption on the operator key or a dedicated
short-lived bootstrap recipient. 4. Medium: plaintext secrets under hosts/*/secrets/* can bypass the hook by path
convention.
Attack surface: the plaintext scanner skips all hosts/*/secrets/_ paths in pre-commit-
hooks.nix:42. If someone adds an unencrypted YAML/text secret in that directory, the
hook intentionally ignores it.
Enforcement: encrypted-at-rest is assumed by directory naming; not verified per file.
Small hardening: add a hook/check that every file under hosts/_/secrets/ is either a
known encrypted .enc file or a SOPS YAML containing sops: metadata; fail on plaintext
files in secrets directories. 5. Medium: initrd SSH recovery authorizes normal user keys, not only break-glass keys.
Attack surface: main exposes initrd SSH on port 2222 in hosts/main/default.nix:89, and
uses all keys from lib/pubkeys.nix:1, including the regular user@NixOS key. A
compromised daily SSH key becomes an initrd-root recovery credential.
Enforcement: key auth is enforced; key separation is only assumed.
Small hardening: create lib/recovery-pubkeys.nix containing only break-glass keys and
use it for boot.initrd.network.ssh.authorizedKeys. 6. Medium: reinstall/bootstrap sends the stable homeserver host identity to an
unauthenticated target path.
Attack surface: scripts/reinstall-homeserver.sh:13 decrypts the homeserver SSH host
private key and passes it via nixos-anywhere --extra-files to root@<target-ip> in
scripts/reinstall-homeserver.sh:22. The installer ISO permits root SSH with repo keys in
hosts/installer/default.nix:7, but there is no pinned installer host key or target
identity check in the wrapper.
Enforcement: secret at rest is enforced; target identity is assumed/TOFU.
Small hardening: require a provided installer host-key fingerprint or temporary
UserKnownHostsFile entry before sending --extra-files; fail closed if the target key is
missing or changed. 7. Medium: real homeserver persistent service data is not disk-encrypted.
Attack surface: homeserver disk layout is plain ext4 for root and /persist in hosts/
homeserver/disko.nix:56, while /persist stores Tailscale state, Vaultwarden, Syncthing,
Grafana, Loki, and Prometheus data in hosts/homeserver/default.nix:253. Physical disk
loss exposes service databases and tailnet state.
Enforcement: no at-rest encryption is enforced for the server.
Small hardening: put at least /persist behind LUKS; use TPM2 unlock plus a documented
recovery passphrase if unattended boot is required. 8. Low: Tailscale ACLs are broad and generated, but not a strong repo-enforced perimeter.
Attack surface: lib/acl.nix:28 allows tag:workstation to tag:server:\_ and admins to \_:\_;
flake.nix:440 only builds the ACL artifact. If Tailscale is the intended boundary, all
server ports are reachable from workstation-tagged nodes.
Enforcement: ACL generation is enforced; application and least-privilege port scope are
assumed.
Small hardening: generate host:port-specific ACLs, e.g. tag:server:443 and explicit SSH
admin rules, and add tests preventing wildcard server access except where intentionally
waived.

Top 3 Effort-To-Value Improvements

1. Lock homeserver network exposure to Tailscale: close global 22/443, allow only
   tailscale0 ports needed.
2. Remove passwordless sudo/trusted Nix user from production hosts by splitting machine-
   common.
3. Add a secrets-directory encryption invariant so plaintext files under hosts/\*/secrets/
   fail CI/pre-commit.

Longer-Term Goals

- Define separate trust tiers for workstation, production server, VM, and recovery
  identities.
- Move break-glass access to dedicated recovery keys, documented rotation, and tested
  recovery drills.
- Add host-level invariants for exposed ports, sudo posture, trusted-users, and Tailscale-
  only services.
- Encrypt production persistent data and document unattended boot versus physical-theft
  tradeoffs.
- Convert generated Tailscale ACLs into least-privilege, port-specific policy with an
  apply/verify workflow.
