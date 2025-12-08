{ config, pkgs, ... }:
{
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
    checkReversePath = "loose";
  };

  services.openssh = {
    enable = true;
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
  };
}
