{ config, lib, ... }:
let
  trustedUsers = lib.unique ([ "root" ] ++ config.profiles.nix.extraTrustedUsers);
  actualTrustedUsers = lib.unique (config.nix.settings.trusted-users or [ ]);
  missingTrustedUsers = lib.filter (user: !(builtins.elem user actualTrustedUsers)) trustedUsers;
  unexpectedTrustedUsers = lib.filter (user: !(builtins.elem user trustedUsers)) actualTrustedUsers;
  trustedUserViolations = lib.filter (msg: msg != "") [
    (lib.optionalString (
      missingTrustedUsers != [ ]
    ) "missing trusted users: ${lib.concatStringsSep ", " missingTrustedUsers}")
    (lib.optionalString (
      unexpectedTrustedUsers != [ ]
    ) "unexpected trusted users: ${lib.concatStringsSep ", " unexpectedTrustedUsers}")
  ];
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

    assertions = [
      {
        assertion = trustedUserViolations == [ ];
        message = "nix.settings.trusted-users must stay scoped to profiles.nix.extraTrustedUsers: ${lib.concatStringsSep "; " trustedUserViolations}";
      }
    ];

    warnings =
      lib.optional (broadTrustedUsers != [ ])
        "nix.settings.trusted-users contains broad trust entries (${lib.concatStringsSep ", " broadTrustedUsers}); prefer exact users unless this is intentional.";
  };
}
