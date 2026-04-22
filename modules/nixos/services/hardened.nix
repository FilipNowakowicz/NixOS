{
  config,
  lib,
  ...
}:
let
  baseHardening = {
    NoNewPrivileges = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    ProtectControlGroups = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectHostname = true;
    ProtectClock = true;
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    RestrictSUIDSGID = true;
    RestrictRealtime = true;
    RestrictNamespaces = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = [ "@system-service" ];
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
    ];
  };

  hardenedServiceType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Apply the hardening baseline to this service.";
      };

      extraConfig = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = ''
          Additional serviceConfig options merged on top of the baseline.
          Set any base option to null to remove it from the final config
          (e.g. PrivateDevices = null for services that need /dev access).
        '';
      };
    };
  };

  cfg = config.services.hardened;
in
{
  options.services.hardened = lib.mkOption {
    type = lib.types.attrsOf hardenedServiceType;
    default = { };
    description = ''
      Apply a security hardening baseline to the named systemd services.
      Each entry merges the base sandbox options with per-service extraConfig.
    '';
  };

  config.systemd.services = lib.mkMerge (
    lib.mapAttrsToList (
      name: serviceCfg:
      lib.mkIf serviceCfg.enable {
        ${name}.serviceConfig =
          let
            extraKeys = lib.attrNames serviceCfg.extraConfig;
            # Base options not touched by extraConfig: apply at mkDefault so nixpkgs modules win.
            passiveBase = lib.filterAttrs (k: v: v != null && !(lib.elem k extraKeys)) baseHardening;
            # extraConfig non-null values: apply at regular priority to override nixpkgs and base.
            activeExtra = lib.filterAttrs (_: v: v != null) serviceCfg.extraConfig;
          in
          lib.mkMerge [
            (lib.mapAttrs (_: lib.mkDefault) passiveBase)
            activeExtra
          ];
      }
    ) cfg
  );
}
