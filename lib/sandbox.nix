# Common systemd service sandbox options for network-facing daemons.
# Provides a restrictive baseline — callers override with // as needed
# (e.g. ReadWritePaths, CapabilityBoundingSet).
{
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
  RestrictAddressFamilies = [
    "AF_UNIX"
    "AF_INET"
    "AF_INET6"
  ];
}
