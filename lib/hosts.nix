# Host registry — single source of truth for all deployed hosts.
# To add a new host: add an entry here, create hosts/<name>/default.nix.
# Fields:
#   role        — human label; ready to drive modules later
#   deploy      — presence generates a deploy-rs node; absence = local-only (main)
#   sshPort     — VM-only; used to filter hosts for the VM script
#   diskSize    — VM-only; used by nixos-anywhere and qemu-img
#   tailnetFQDN — per-host Tailscale FQDN; unused metadata for now (host configs read lib/network.nix directly)
#   tailscale   — Tailscale metadata; presence means host is on the tailnet
#     .tag      — Tailscale tag assigned to this host (without "tag:" prefix)
#   backup      — drives modules/nixos/profiles/backup.nix retention policy
#     .class    — "critical" (14d/8w/6m/2y) | "standard" (7d/4w/3m); absent = no backup module
{
  main = {
    role = "workstation";
    tailscale.tag = "workstation";
    backup.class = "standard";
  };

  homeserver = {
    role = "homeserver";
    tailnetFQDN = "homeserver.filip-nowakowicz.ts.net";
    tailscale.tag = "server";
    deploy.sshUser = "user";
    backup.class = "critical";
  };

  vm = {
    role = "vm";
    sshPort = 2222;
    diskSize = "40G";
    deploy.sshUser = "user";
  };

  homeserver-vm = {
    role = "homeserver-vm";
    ip = "10.0.100.2";
    backup.class = "critical";
  };
}
