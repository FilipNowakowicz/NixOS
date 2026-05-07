{ lib, hostMeta, ... }:
let
  backup = hostMeta.backup or { };
  backupClass = backup.class or null;
  backupName = backup.name or "local";

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
  services.restic.backups.${backupName} = {
    initialize = true;
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
    pruneOpts = pruneOptsByClass.${backupClass};
  };
}
