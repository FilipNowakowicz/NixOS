{ lib, ... }:
{
  # ── Firewall ───────────────────────────────────────────────────────────
  networking.firewall.enable = true;
  networking.nftables.enable = true;

  # ── SSH ────────────────────────────────────────────────────────────────
  services.openssh = {
    enable = lib.mkDefault false;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # ── Intrusion Prevention ───────────────────────────────────────────────
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "30m";
    "bantime-increment" = {
      enable = true;
      maxtime = "24h";
      overalljails = true;
    };
  };

  # ── Kernel Hardening ───────────────────────────────────────────────────
  boot.kernel.sysctl = {
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
  };
}
