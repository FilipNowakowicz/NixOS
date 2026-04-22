{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.systemd-failure-notify;

  notifyScript = pkgs.writeScript "systemd-failure-notify" ''
    #!/usr/bin/env bash
    SERVICE_NAME="''${SYSTEMD_UNIT%.*}"
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    # Log to journal
    echo "[$TIMESTAMP] Service $SERVICE_NAME failed unexpectedly" | systemd-cat -t systemd-failure-notify -p warning

    # Try to send desktop notification if display is available
    if [[ -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
      export PATH="${pkgs.libnotify}/bin:$PATH"
      notify-send -a "systemd" -u critical "Service Failed" "$SERVICE_NAME failed at $TIMESTAMP" 2>/dev/null || true
    fi
  '';
in
{
  options.services.systemd-failure-notify = {
    enable = lib.mkEnableOption "desktop notifications for systemd service failures";

    services = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of service names to attach failure notifications to (e.g. ['nginx' 'redis-server'])";
      example = [
        "nginx"
        "postgresql"
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ libnotify ];

    # Template unit for failure notifications
    systemd.units."notify-failure@.service" = {
      text = ''
        [Unit]
        Description=Notify on %i failure
        After=syslog.target network-online.target remote-fs.target nss-lookup.target

        [Service]
        Type=oneshot
        ExecStart=${pkgs.bash}/bin/bash ${notifyScript}
        StandardOutput=journal
        StandardError=journal
      '';
    };

    # Attach OnFailure to specified services
    systemd.services = lib.mkMerge (
      map (serviceName: {
        "${serviceName}" = {
          onFailure = [ "notify-failure@${serviceName}.service" ];
        };
      }) cfg.services
    );
  };
}
