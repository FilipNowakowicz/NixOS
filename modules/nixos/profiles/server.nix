{ ... }:
{
  zramSwap.enable = true;

  nix.settings.trusted-users = [ "root" "user" ];

  security.sudo.extraRules = [
    {
      users   = [ "user" ];
      commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
    }
  ];
}
