{ config, lib, ... }:
let
  trustedUsers = lib.unique ([ "root" ] ++ config.profiles.nix.extraTrustedUsers);
  broadTrustedUsers = lib.filter (user: user == "*" || lib.hasPrefix "@" user) trustedUsers;
in
{
  options.profiles.nix.extraTrustedUsers = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Additional users to trust in the Nix daemon beyond the fleet baseline.";
  };

  config = {
    nix.settings.trusted-users = trustedUsers;

    warnings =
      lib.optional (broadTrustedUsers != [ ])
        "nix.settings.trusted-users contains broad trust entries (${lib.concatStringsSep ", " broadTrustedUsers}); prefer exact users unless this is intentional.";
  };
}
