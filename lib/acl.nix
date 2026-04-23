# Tailscale ACL generator — derives tag owners and base rules from the host
# registry. Feed the output to builtins.toJSON for acl.hujson.
{ lib }:
let
  tailscaleHosts = hosts: lib.filterAttrs (_: cfg: cfg ? tailscale) hosts;

  collectTagNames =
    hosts: lib.unique (map (cfg: cfg.tailscale.tag) (lib.attrValues (tailscaleHosts hosts)));

  mkTagOwners =
    tags:
    lib.listToAttrs (
      map (tag: {
        name = "tag:${tag}";
        value = [ "autogroup:admin" ];
      }) tags
    );

in
{
  # Generate a Tailscale ACL attrset from the host registry.
  # Hosts without a `tailscale` attribute are ignored.
  # Serialize with builtins.toJSON to get acl.hujson content.
  mkAcl = hostRegistry: {
    tagOwners = mkTagOwners (collectTagNames hostRegistry);
    acls = [
      {
        action = "accept";
        src = [ "tag:workstation" ];
        dst = [ "tag:server:*" ];
      }
      {
        action = "accept";
        src = [ "autogroup:admin" ];
        dst = [ "*:*" ];
      }
    ];
  };
}
