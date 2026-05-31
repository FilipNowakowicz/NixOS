# Mimir ruler alert rules and minimal Alertmanager config.
# Rules are provisioned declaratively via mimir.service's preStart, which runs as
# the mimir user inside the unit so it can write into the DynamicUser-owned
# StateDirectory. (systemd-tmpfiles cannot: it refuses the "unsafe path
# transition" into /var/lib/private/mimir, owned by the dynamic mimir uid, and
# silently skips the copy — leaving the ruler with zero rule groups.)
# Mimir's ruler polls ruler_storage and loads the file on the next sync; preStart
# runs on every (re)start so redeploys pick up rule changes.
#
# The rule/alertmanager data lives in lib/observability-alerts.nix so the
# observability-alerts-lint flake check (promtool check rules) validates the
# exact same source this module renders. Thresholds are documented there.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.profiles.observability;
  mkYaml = name: data: (pkgs.formats.yaml { }).generate name data;

  alertData = import ../../../../lib/observability-alerts.nix;

  rulesFile = mkYaml "infrastructure-alerts.yaml" alertData.rules;

  # Alertmanager config layered on the shared base in lib/observability-alerts.nix
  # (null route + null receiver). When `alertWebhookUrlFile` is set, alerts are
  # routed to a webhook receiver (ntfy.sh format: POST the alert JSON to the URL).
  # Override further in host config via lib.mkForce if needed.
  webhookEnabled = cfg.alertWebhookUrlFile != null;
  alertmanagerFile = mkYaml "alertmanager.yaml" (
    alertData.alertmanager
    // lib.optionalAttrs webhookEnabled {
      route = alertData.alertmanager.route // {
        receiver = "webhook";
      };
      receivers = alertData.alertmanager.receivers ++ [
        {
          name = "webhook";
          webhook_configs = [
            {
              url_file = toString cfg.alertWebhookUrlFile;
              send_resolved = true;
            }
          ];
        }
      ];
    }
  );
in
{
  config = lib.mkIf (cfg.enable && cfg.mimir.enable) {
    services.mimir.configuration.ruler = {
      alertmanager_url = "http://127.0.0.1:9009/alertmanager";
    };

    # multitenancy_enabled = false ⇒ the tenant is "anonymous", so ruler_storage
    # and alertmanager_storage read rules/config from the <tenant> subdirectory.
    # $STATE_DIRECTORY resolves to /var/lib/mimir inside the unit; preStart runs
    # as the mimir user, which owns the StateDirectory, so the writes succeed.
    systemd.services.mimir.preStart = ''
      ${pkgs.coreutils}/bin/install -D -m 0640 \
        ${rulesFile} "$STATE_DIRECTORY/rules/anonymous/infrastructure-alerts.yaml"
      ${pkgs.coreutils}/bin/install -D -m 0640 \
        ${alertmanagerFile} "$STATE_DIRECTORY/alertmanager/anonymous/alertmanager.yaml"
    '';
  };
}
