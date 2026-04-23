# Centralized network identifiers used across hosts.
# tailnetFQDN is derived from the host registry to avoid duplication.
let
  hosts = import ./hosts.nix;
in
{
  inherit (hosts.homeserver) tailnetFQDN;
}
