_: {
  security.sudo.wheelNeedsPassword = false;

  services.openssh.openFirewall = true;

  profiles.nix.extraTrustedUsers = [ "user" ];
}
