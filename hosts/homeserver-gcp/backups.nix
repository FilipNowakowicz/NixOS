{ config, pkgs, ... }:
{
  systemd.services = {
    # Stamp the freshness metric only when the restic backup ExecStart exits 0.
    # ExecStartPost runs for every ExecStart result (including a partial or
    # prune-failed run), so gate on $EXIT_STATUS to avoid reporting a
    # false-fresh timestamp that would mask a broken backup in alerts/badges.
    restic-backups-b2.serviceConfig.ExecStartPost = pkgs.writeShellScript "restic-backup-metrics" ''
      [ "''${EXIT_STATUS:-}" = "0" ] || exit 0
      tmp=/var/lib/node-exporter-textfiles/restic_backup.prom.tmp
      {
        echo "# HELP restic_last_backup_timestamp_seconds Unix timestamp of last successful restic backup"
        echo "# TYPE restic_last_backup_timestamp_seconds gauge"
        echo "restic_last_backup_timestamp_seconds $(date +%s)"
      } > "$tmp"
      mv "$tmp" /var/lib/node-exporter-textfiles/restic_backup.prom
    '';

    restic-check-b2 = {
      description = "Restic B2 repository integrity check";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment.RESTIC_PASSWORD_FILE = config.sops.secrets.restic_password.path;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.restic}/bin/restic check --repository-file=${config.sops.secrets.restic_repository.path} --read-data-subset=1G";
        ExecStartPost = pkgs.writeShellScript "restic-check-metrics" ''
          tmp=/var/lib/node-exporter-textfiles/restic_check.prom.tmp
          {
            echo "# HELP restic_last_check_timestamp_seconds Unix timestamp of last successful restic integrity check"
            echo "# TYPE restic_last_check_timestamp_seconds gauge"
            echo "restic_last_check_timestamp_seconds $(date +%s)"
          } > "$tmp"
          mv "$tmp" /var/lib/node-exporter-textfiles/restic_check.prom
        '';
        EnvironmentFile = config.sops.secrets.b2_credentials.path;
      };
    };
  };

  systemd.timers.restic-check-b2 = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      RandomizedDelaySec = "2h";
      Persistent = true;
    };
  };

  services.restic.backups.b2 = {
    paths = [
      "/var/lib/vaultwarden"
      "/var/lib/grafana"
      "/var/lib/private/AdGuardHome"
    ];
    # Grafana keeps live SQLite state (grafana.db + WAL) at /var/lib/grafana.
    # Backing up the live file risks capturing a torn mid-write state, so emit a
    # consistent snapshot with sqlite3 .backup and exclude the live db/WAL files.
    backupPrepareCommand = ''
      ${pkgs.sqlite}/bin/sqlite3 /var/lib/grafana/grafana.db ".backup '/var/lib/grafana/grafana.db.backup'"
    '';
    exclude = [
      "/var/lib/grafana/grafana.db"
      "/var/lib/grafana/grafana.db-wal"
      "/var/lib/grafana/grafana.db-shm"
    ];
    repositoryFile = config.sops.secrets.restic_repository.path;
    passwordFile = config.sops.secrets.restic_password.path;
    environmentFile = config.sops.secrets.b2_credentials.path;
  };
}
