{ lib, ... }:
{
  # ── Sops (shared base — all hosts set defaultSopsFile and declare secrets) ──
  sops = {
    defaultSopsFormat = "yaml";
    # SSH-key-based decryption; microvm-guest.nix overrides this to mkForce []
    # in favour of a virtiofs-injected age key.
    age.sshKeyPaths = lib.mkDefault [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  # ── User (SSH authorised keys) ──────────────────────────────────────────────
  users.users.user.openssh.authorizedKeys.keys = import ../../../lib/pubkeys.nix;
}
