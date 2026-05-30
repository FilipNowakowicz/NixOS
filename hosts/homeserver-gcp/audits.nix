{
  config,
  lib,
  pkgs,
  ...
}:
let
  gen = import ../../lib/generators.nix { inherit lib; };
  inherit (gen.systemd) timer;
  inherit (config.lib.profiles.observability) mkPromScript;
in
{
  systemd = {
    services = {
      lynis-audit = {
        description = "Lynis security audit";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "lynis-audit" ''
            report=/tmp/lynis-report.dat

            ${pkgs.lynis}/bin/lynis audit system \
              --quiet --no-colors --report-file "$report" 2>/dev/null
            rc=$?
            # lynis exits 0 (clean) or non-zero on warnings — treat all as success
            # if the report file wasn't written, the scan itself failed
            if [ ! -f "$report" ]; then
              echo "lynis did not produce a report" >&2
              exit 1
            fi

            hardening_index=$(grep "^hardening_index=" "$report" | cut -d= -f2)
            warning_count=$(grep -c "^warning\\[\\]=" "$report" || true)
            suggestion_count=$(grep -c "^suggestion\\[\\]=" "$report" || true)
            : "''${hardening_index:=0}"
            export hardening_index warning_count suggestion_count
            ${mkPromScript {
              name = "lynis.prom";
              lines = [
                "# HELP lynis_hardening_index Security hardening index (0-100)"
                "# TYPE lynis_hardening_index gauge"
                "lynis_hardening_index $hardening_index"
                "# HELP lynis_warnings_total Number of lynis warnings"
                "# TYPE lynis_warnings_total gauge"
                "lynis_warnings_total $warning_count"
                "# HELP lynis_suggestions_total Number of lynis suggestions"
                "# TYPE lynis_suggestions_total gauge"
                "lynis_suggestions_total $suggestion_count"
                "# HELP lynis_scan_timestamp_seconds Unix timestamp of last successful audit"
                "# TYPE lynis_scan_timestamp_seconds gauge"
                "lynis_scan_timestamp_seconds $(${pkgs.coreutils}/bin/date +%s)"
              ];
            }}
            rm -f "$report"
          '';
        };
      };

      vulnix-scan = {
        description = "Vulnix CVE scan of current system closure";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "vulnix-scan" ''
            whitelist=${./vulnix-whitelist.toml}

            # --system scans /run/current-system; -j = JSON output
            # NVD data is downloaded and cached in /var/cache/vulnix
            # vulnix exit codes: 0 = clean, 2 = CVEs found, other = error
            json=$(${pkgs.vulnix}/bin/vulnix -S -j \
              --whitelist "$whitelist" \
              --cache-dir /var/cache/vulnix 2>/dev/null) || true

            # validate JSON — if vulnix errored, output won't parse and we abort
            pkg_count=$(printf '%s' "$json" | ${pkgs.jq}/bin/jq 'length // 0') || {
              echo "vulnix produced invalid output" >&2; exit 1;
            }
            cve_count=$(printf '%s' "$json" | ${pkgs.jq}/bin/jq '[.[].affected_by | length] | add // 0')
            export pkg_count cve_count

            ${mkPromScript {
              name = "vulnix.prom";
              lines = [
                "# HELP vulnix_affected_packages_total Packages with known CVEs after whitelist"
                "# TYPE vulnix_affected_packages_total gauge"
                "vulnix_affected_packages_total $pkg_count"
                "# HELP vulnix_cve_total CVE findings after whitelist"
                "# TYPE vulnix_cve_total gauge"
                "vulnix_cve_total $cve_count"
                "# HELP vulnix_scan_timestamp_seconds Unix timestamp of last successful scan"
                "# TYPE vulnix_scan_timestamp_seconds gauge"
                "vulnix_scan_timestamp_seconds $(${pkgs.coreutils}/bin/date +%s)"
              ];
            }}
          '';
        };
      };
    };

    timers = {
      lynis-audit = timer {
        schedule = "daily";
        jitter = "1h";
      };

      vulnix-scan = timer {
        schedule = "daily";
        jitter = "1h";
      };
    };

    tmpfiles.rules = [
      "d /var/cache/vulnix 0750 root root -"
    ];
  };
}
