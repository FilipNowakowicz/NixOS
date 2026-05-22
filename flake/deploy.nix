{
  deploy-rs,
  lib,
  hostRegistry,
  allNixosConfigs,
  ciNixosConfigs,
}:
let
  deployableHosts = lib.filterAttrs (_: cfg: cfg ? deploy) hostRegistry;

  mkDeployNodes =
    nixosConfigs:
    lib.mapAttrs (name: cfg: {
      hostname = name;
      inherit (cfg.deploy) sshUser;
      magicRollback = true;
      autoRollback = true;
      remoteBuild = true;
      profiles.system = {
        user = "root";
        path = deploy-rs.lib.${cfg.system}.activate.nixos nixosConfigs.${name};
      };
    }) deployableHosts;

  allDeployNodes = mkDeployNodes allNixosConfigs;

  ciDeployNodes = mkDeployNodes ciNixosConfigs;
in
{
  inherit allDeployNodes ciDeployNodes;
}
