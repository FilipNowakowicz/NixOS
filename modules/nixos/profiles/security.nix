{ lib, ... }:
{
  networking.firewall.enable = true;

  services.openssh = {

    enable = lib.mkDefault false;

    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;

      PermitEmptyPasswords = false;
    };
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };

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
