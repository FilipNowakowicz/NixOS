{ config, lib, ... }:
let
  hostRegistry = import ../../../lib/hosts.nix;
  hostEntry = hostRegistry.${config.networking.hostName} or { };
  backupClass = hostEntry.backup.class or null;

  pruneOptsByClass = {
    critical = [
      "--keep-daily 14"
      "--keep-weekly 8"
      "--keep-monthly 6"
      "--keep-yearly 2"
    ];
    standard = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 3"
    ];
  };
in
lib.mkIf (backupClass != null) {
  services.restic.backups.local = {
    initialize = true;
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
    pruneOpts = pruneOptsByClass.${backupClass};
  };
}
