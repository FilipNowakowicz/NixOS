# Tailscale ACL generator — derives tag owners and base rules from the host
# registry. Feed the output to builtins.toJSON for acl.hujson.
# Workstation-to-server access is derived from explicit per-host metadata:
# `tailscale.tag`, `tailscale.acceptFrom`, and `tailnetFQDN` when available.
{ lib }:
let
  tailscaleHosts = hosts: lib.filterAttrs (_: cfg: cfg ? tailscale) hosts;

  collectTagNames =
    hosts: lib.unique (map (cfg: cfg.tailscale.tag) (lib.attrValues (tailscaleHosts hosts)));

  sortedUnique = values: builtins.sort builtins.lessThan (lib.unique values);

  mkTagOwners =
    tags:
    lib.listToAttrs (
      map (tag: {
        name = "tag:${tag}";
        value = [ "autogroup:admin" ];
      }) tags
    );

  destinationHost = hostName: cfg: cfg.tailnetFQDN or hostName;

  explicitAllowMap =
    hostRegistry:
    builtins.foldl' (
      acc: hostName:
      let
        cfg = hostRegistry.${hostName};
        acceptFrom = cfg.tailscale.acceptFrom or { };
        srcTags = builtins.sort builtins.lessThan (builtins.attrNames acceptFrom);
        hostDsts = map (
          srcTag:
          let
            dsts = map (port: "${destinationHost hostName cfg}:${toString port}") (
              sortedUnique acceptFrom.${srcTag}
            );
          in
          {
            inherit srcTag dsts;
          }
        ) srcTags;
      in
      builtins.foldl' (
        innerAcc: rule:
        innerAcc
        // {
          ${rule.srcTag} = (innerAcc.${rule.srcTag} or [ ]) ++ rule.dsts;
        }
      ) acc hostDsts
    ) { } (builtins.sort builtins.lessThan (builtins.attrNames (tailscaleHosts hostRegistry)));

  mkExplicitAclRules =
    hostRegistry:
    let
      allowMap = explicitAllowMap hostRegistry;
      srcTags = builtins.sort builtins.lessThan (builtins.attrNames allowMap);
    in
    map (srcTag: {
      action = "accept";
      src = [ "tag:${srcTag}" ];
      dst = sortedUnique allowMap.${srcTag};
    }) srcTags;

in
{
  # Generate a Tailscale ACL attrset from the host registry.
  # Hosts without a `tailscale` attribute are ignored.
  # The output is intentionally minimal: tag owners plus explicit allow rules.
  # Serialize with builtins.toJSON to get acl.hujson content.
  mkAcl = hostRegistry: {
    tagOwners = mkTagOwners (collectTagNames hostRegistry);
    acls = (mkExplicitAclRules hostRegistry) ++ [
      {
        # Deliberate break-glass access for tailnet admins.
        action = "accept";
        src = [ "autogroup:admin" ];
        dst = [ "*:*" ];
      }
    ];
  };
}
