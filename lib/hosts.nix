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
#   backup      — metadata; ready to drive a backup module later
{
  main = {
    role = "workstation";
    tailscale.tag = "workstation";
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
  };
}
