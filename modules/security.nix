{ lib, ... }:
{
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
    checkReversePath = "loose";
  };

  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = true;
    };
  };

  security = {
    acme = {
      acceptTerms = true;
      defaults.email = "admin@example.com";
    };

    sudo = {
      enable = true;
      wheelNeedsPassword = false;
    };

    rtkit.enable = true;
    lockKernelModules = lib.mkDefault true;
  };

  boot.kernel.sysctl = {
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
  };
}
