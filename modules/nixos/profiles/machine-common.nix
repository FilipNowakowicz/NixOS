{
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  nix.settings.trusted-users = [
    "root"
    "user"
  ];
}
