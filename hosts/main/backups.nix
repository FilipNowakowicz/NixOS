{ config, pkgs, ... }:
{
  # Hidden maintenance mount for the filesystem top-level. btrbk snapshots
  # subvolumes by their real top-level names (`@home`, `@persist`) rather than
  # via nested mount paths.
  fileSystems."/.btrfs-root" = {
    device = "/dev/disk/by-label/main-root";
    fsType = "btrfs";
    options = [
      "subvol=/"
      "noatime"
      "discard=async"
    ];
  };

  services = {
    btrbk.instances.local = {
      onCalendar = "daily";
      snapshotOnly = true;
      settings = {
        snapshot_preserve_min = "2d";
        snapshot_preserve = "14d";
        volume."/.btrfs-root" = {
          snapshot_dir = ".snapshots";
          subvolume = {
            "@home" = { };
            "@persist" = { };
          };
        };
      };
    };

    restic.backups.local = {
      paths = [
        "/home/user/.ssh"
        "/home/user/.gnupg"
        "/home/user/nix"
        "/home/user/.mozilla/firefox"
        "/home/user/.config/mozilla/firefox"
        "/home/user/.config/spotify"
        "/home/user/.config/discord"
        "/home/user/.config/gh"
        "/home/user/.config/gcloud"
        "/home/user/.local/share/Anki2"
        "/home/user/.config/chromium"
        "/home/user/.local/share/kwalletd"
        "/home/user/.codex"
        "/home/user/.claude"
        "/home/user/.claude.json"
        "/home/user/.config/sops"
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/NetworkManager/system-connections"
        "/etc/mullvad-vpn"
        "/var/lib/tailscale"
        "/var/lib/bluetooth"
        "/var/lib/fprint"
        "/var/lib/sbctl"
        "/var/lib/usbguard"
      ];
      exclude = [
        # Token/credential caches — not durable; regenerated on next gcloud auth
        "/home/user/.config/gcloud/access_tokens.db"
        "/home/user/.config/gcloud/credentials.db"
        "/home/user/.config/gcloud/logs"
        "/home/user/.config/gcloud/legacy_credentials"
      ];
      repositoryFile = config.sops.secrets.restic_repository.path;
      passwordFile = config.sops.secrets.restic_password.path;
      environmentFile = config.sops.secrets.b2_credentials.path;
    };
  };

  systemd = {
    services = {
      restic-backups-local.serviceConfig.ExecStartPost = pkgs.writeShellScript "restic-backup-metrics" ''
        tmp=/var/lib/node-exporter-textfiles/restic_backup.prom.tmp
        {
          echo "# HELP restic_last_backup_timestamp_seconds Unix timestamp of last successful restic backup"
          echo "# TYPE restic_last_backup_timestamp_seconds gauge"
          echo "restic_last_backup_timestamp_seconds $(date +%s)"
        } > "$tmp"
        mv "$tmp" /var/lib/node-exporter-textfiles/restic_backup.prom
      '';

      btrbk-local-snapshot-dir = {
        description = "Ensure btrbk local snapshot directory exists";
        requiredBy = [ "btrbk-local.service" ];
        before = [ "btrbk-local.service" ];
        unitConfig.RequiresMountsFor = "/.btrfs-root";
        serviceConfig.Type = "oneshot";
        script = ''
          ${pkgs.coreutils}/bin/install -d -m 0750 -o btrbk -g btrbk /.btrfs-root/.snapshots
        '';
      };

      restic-check-local = {
        description = "Restic workstation repository integrity check";
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

    timers.restic-check-local = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        RandomizedDelaySec = "2h";
        Persistent = true;
      };
    };
  };
}
