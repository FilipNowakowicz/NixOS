{
  lib,
  pkgs,
  hostRegistry,
  allNixosConfigs,
}:
let
  repoBaseUrl = "https://github.com/FilipNowakowicz/NixOS";
  docsBaseUrl = "${repoBaseUrl}/blob/main";
  invariants = import ../lib/invariants.nix { inherit lib pkgs; };

  hostHealth =
    name: cfg:
    let
      commonAssertions = [
        {
          name = "has stateVersion";
          check = c: c.system.stateVersion != null;
        }
        {
          name = "SSH hosts enforce hardened fail2ban";
          check =
            c:
            let
              violations = lib.filter (msg: msg != "") [
                (lib.optionalString (!c.services.fail2ban.enable) "services.fail2ban.enable must be true")
                (lib.optionalString (c.services.fail2ban.maxretry > 3) "services.fail2ban.maxretry must be <= 3")
                (lib.optionalString (c.services.fail2ban.bantime != "30m") "services.fail2ban.bantime must be \"30m\"")
                (lib.optionalString (!c.services.fail2ban."bantime-increment".enable) "services.fail2ban.bantime-increment.enable must be true")
                (lib.optionalString (c.services.fail2ban."bantime-increment".maxtime == null) "services.fail2ban.bantime-increment.maxtime must be set")
              ];
            in
            if !c.services.openssh.enable then
              true
            else
              violations == [ ];
        }
        {
          name = "observability client uses canonical ingest username";
          check =
            c:
            let
              clientProfile = c.profiles.observability-client or { };
              obsProfile = c.profiles.observability or { };
              ingestAuth = obsProfile.ingestAuth or { };
              clientEnabled = clientProfile.enable or false;
              username = ingestAuth.username or "telemetry";
            in
            !clientEnabled || username == "telemetry";
        }
      ];

      hostSpecificAssertions =
        if name == "main" then
          [
            {
              name = "main SSH stays tailnet-only";
              check =
                c:
                c.services.openssh.enable
                && !c.services.openssh.openFirewall
                && c.services.tailscale.enable
                && c.services.tailscale.openFirewall;
            }
            {
              name = "main USBGuard stays deny-default";
              check =
                c:
                let
                  rules = c.services.usbguard.rules or "";
                in
                c.services.usbguard.enable && lib.hasInfix "allow id " rules && lib.hasInfix "reject" rules;
            }
            {
              name = "main local backup covers critical paths";
              check =
                c:
                let
                  backup = c.services.restic.backups.local or null;
                in
                backup != null
                && (backup.paths or [ ]) == [
                  "/home/user/.ssh"
                  "/home/user/.gnupg"
                  "/home/user/nix"
                ]
                && (backup.passwordFile or "") != ""
                && lib.hasPrefix "/run/secrets/" (backup.passwordFile or "")
                && backup.initialize
                && (backup.timerConfig.OnCalendar or null) == "daily";
            }
          ]
        else if name == "vm" then
          [
            {
              name = "passwordless sudo enabled";
              check = c: !c.security.sudo.wheelNeedsPassword;
            }
          ]
        else if name == "homeserver-vm" then
          [
            {
              name = "firewall enabled";
              check = c: c.networking.firewall.enable;
            }
            {
              name = "passwordless sudo enabled";
              check = c: !c.security.sudo.wheelNeedsPassword;
            }
          ]
        else if name == "homeserver" then
          [
            {
              name = "no passwordless sudo";
              check = c: c.security.sudo.wheelNeedsPassword;
            }
            {
              name = "firewall enabled";
              check = c: c.networking.firewall.enable;
            }
            {
              name = "SSH and HTTPS are not globally open";
              check = c: !(lib.any (port: builtins.elem port (c.networking.firewall.allowedTCPPorts or [ ])) [ 22 443 ]);
            }
            {
              name = "SSH and HTTPS stay Tailscale-only";
              check =
                c:
                let
                  interfaces = c.networking.firewall.interfaces or { };
                  tailscaleNetwork = interfaces.tailscale0.allowedTCPPorts or [ ];
                in
                builtins.all (port: builtins.elem port tailscaleNetwork) [
                  22
                  443
                ];
            }
          ]
        else
          [ ];

      results = invariants.evaluateAssertions (commonAssertions ++ hostSpecificAssertions ++ invariants.mkRegistryAssertions name hostRegistry.${name}) cfg.config;
      failed = lib.filter (result: !result.passed) results;
    in
    {
      invariantResults = results;
      invariantPassed = builtins.length results - builtins.length failed;
      invariantFailed = builtins.length failed;
      invariantStatus = if failed == [ ] then "pass" else "warn";
    };

  extractHost =
    name: cfg:
    let
      meta = hostRegistry.${name};
      c = cfg.config;
      health = hostHealth name cfg;
    in
    {
      inherit name;
      inherit (meta) system;
      closurePath = builtins.unsafeDiscardStringContext (toString c.system.build.toplevel);
      inherit (c.system) stateVersion;
      tailscaleTag = meta.tailscale.tag or null;
      tailnetFQDN = meta.tailnetFQDN or null;
      ip = meta.ip or null;
      deployable = meta ? deploy;
      backupClass = meta.backup.class or null;
      homeManagerRole = meta.homeManager.role or null;
      homeManagerProfiles = meta.homeManager.profiles or [ ];
      impermanence = (c.environment.persistence or { }) != { };
      openTCPPorts = c.networking.firewall.allowedTCPPorts or [ ];
      openUDPPorts = c.networking.firewall.allowedUDPPorts or [ ];
      profiles = {
        desktop = c.programs.hyprland.enable or false;
        security = c.services.fail2ban.enable or false;
        observability = c.profiles.observability.enable or false;
        observabilityClient = c.profiles.observability-client.enable or false;
      };
      services = {
        openssh = c.services.openssh.enable;
        tailscale = c.services.tailscale.enable;
        firewall = c.networking.firewall.enable;
        fail2ban = c.services.fail2ban.enable;
        vaultwarden = c.services.vaultwarden.enable or false;
        syncthing = c.services.syncthing.enable or false;
        hyprland = c.programs.hyprland.enable or false;
        observabilityStack = c.profiles.observability.enable or false;
        observabilityClient = c.profiles.observability-client.enable or false;
        usbguard = c.services.usbguard.enable or false;
        lanzaboote = c.boot.lanzaboote.enable or false;
      };
      inherit health;
    };

  goalsData = map (
    goal:
    goal
    // {
      docs = map (path: {
        inherit path;
        url = "${docsBaseUrl}/${path}";
      }) (goal.docs or [ ]);
    }
  ) (import ../lib/goals.nix);

  hostsData = lib.mapAttrsToList extractHost allNixosConfigs;

  hostSpec = builtins.concatStringsSep "\n" (
    map (host: "${host.name}\t${host.closurePath}") hostsData
  );

  dataJson = builtins.toJSON {
    hosts = hostsData;
    goals = goalsData;
    repository = repoBaseUrl;
  };

  html = ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>NixOS Fleet Inventory</title>
      <style>
        :root {
          --bg: #0d1117;
          --surface: #161b22;
          --surface-2: #11161d;
          --border: #30363d;
          --text: #e6edf3;
          --muted: #7d8590;
          --green: #3fb950;
          --red: #f85149;
          --blue: #58a6ff;
          --yellow: #d29922;
          --purple: #bc8cff;
          --orange: #f0883e;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          background:
            radial-gradient(circle at top left, rgba(88, 166, 255, 0.12), transparent 28%),
            radial-gradient(circle at top right, rgba(188, 140, 255, 0.10), transparent 24%),
            var(--bg);
          color: var(--text);
          font-family: 'Cascadia Code', 'Fira Code', 'JetBrains Mono', monospace;
          font-size: 13px;
          padding: 2rem;
          line-height: 1.5;
        }
        h1 { font-size: 1.4rem; color: var(--blue); margin-bottom: 0.25rem; }
        .subtitle { color: var(--muted); font-size: 0.85rem; margin-bottom: 1.25rem; }

        /* Summary strip */
        .summary {
          display: flex;
          flex-wrap: wrap;
          gap: 1.5rem;
          background: linear-gradient(180deg, rgba(22, 27, 34, 0.92), rgba(17, 22, 29, 0.96));
          border: 1px solid var(--border);
          border-radius: 10px;
          padding: 0.75rem 1.25rem;
          margin-bottom: 1.25rem;
          font-size: 0.8rem;
          box-shadow: 0 18px 40px rgba(0, 0, 0, 0.18);
        }
        .stat { display: flex; flex-direction: column; }
        .stat-value { font-size: 1.3rem; font-weight: 600; color: var(--text); line-height: 1.2; }
        .stat-label { color: var(--muted); font-size: 0.72rem; }
        .stat-warn .stat-value { color: var(--yellow); }

        /* Panels */
        .operator-row {
          display: grid;
          grid-template-columns: minmax(0, 1.8fr) minmax(320px, 0.95fr);
          gap: 1rem;
          margin-bottom: 1.25rem;
          align-items: start;
        }
        .panel {
          background: linear-gradient(180deg, rgba(22, 27, 34, 0.95), rgba(17, 22, 29, 0.98));
          border: 1px solid var(--border);
          border-radius: 10px;
          padding: 1rem 1.1rem 1.1rem;
          box-shadow: 0 18px 40px rgba(0, 0, 0, 0.16);
        }
        .panel-header {
          display: flex;
          justify-content: space-between;
          align-items: flex-end;
          gap: 0.75rem;
          margin-bottom: 0.9rem;
          padding-bottom: 0.7rem;
          border-bottom: 1px solid rgba(125, 133, 144, 0.2);
        }
        .panel-title { font-size: 0.95rem; color: var(--text); font-weight: 700; }
        .panel-subtitle { color: var(--muted); font-size: 0.74rem; max-width: 50ch; }
        .panel-actions {
          display: flex;
          gap: 0.4rem;
          align-items: center;
          flex-wrap: wrap;
        }
        .panel-action {
          font-family: inherit;
          font-size: 0.72rem;
          padding: 3px 10px;
          border-radius: 10px;
          border: 1px solid var(--border);
          background: var(--surface);
          color: var(--muted);
          cursor: pointer;
        }
        .panel-action:hover { color: var(--text); border-color: var(--muted); }
        .panel-action.active { color: var(--blue); border-color: var(--blue); background: #1c2d4a; }

        /* Filter bar */
        .filters {
          display: flex;
          flex-wrap: wrap;
          gap: 0.4rem;
          margin-bottom: 1rem;
          align-items: center;
          min-width: 0;
        }
        .filter-label { color: var(--muted); font-size: 0.75rem; margin-right: 0.25rem; }
        .filter-btn {
          font-family: inherit;
          font-size: 0.72rem;
          padding: 3px 10px;
          border-radius: 10px;
          border: 1px solid var(--border);
          background: var(--surface);
          color: var(--muted);
          cursor: pointer;
          transition: border-color 0.15s, color 0.15s;
        }
        .filter-btn:hover { color: var(--text); border-color: var(--muted); }
        .filter-btn.active { color: var(--blue); border-color: var(--blue); background: #1c2d4a; }
        .filter-group-label {
          color: var(--muted);
          font-size: 0.68rem;
          letter-spacing: 0.08em;
          text-transform: uppercase;
          margin-left: 0.5rem;
        }
        .filter-details {
          width: 100%;
          border: 1px solid rgba(125, 133, 144, 0.18);
          border-radius: 8px;
          background: rgba(12, 17, 23, 0.3);
          padding: 0.35rem 0.55rem;
        }
        .filter-summary {
          cursor: pointer;
          color: var(--muted);
          font-size: 0.72rem;
          list-style: none;
        }
        .filter-summary::-webkit-details-marker { display: none; }
        .filter-details-body {
          padding-top: 0.55rem;
          display: flex;
          flex-direction: column;
          gap: 0.5rem;
        }

        /* Goals board */
        .goal-board {
          display: grid;
          grid-template-columns: repeat(4, minmax(0, 1fr));
          gap: 0.8rem;
        }
        .goal-column {
          background: rgba(12, 17, 23, 0.46);
          border: 1px solid rgba(125, 133, 144, 0.18);
          border-radius: 8px;
          padding: 0.8rem;
          min-height: 280px;
          min-width: 0;
        }
        .goal-column-header {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 0.5rem;
          margin-bottom: 0.75rem;
        }
        .goal-column-title {
          font-size: 0.78rem;
          text-transform: uppercase;
          letter-spacing: 0.08em;
          color: var(--muted);
        }
        .goal-column-count {
          color: var(--blue);
          font-size: 0.75rem;
        }
        .goal-list {
          display: flex;
          flex-direction: column;
          gap: 0.65rem;
        }
        .goal-empty {
          color: var(--muted);
          font-size: 0.78rem;
          border: 1px dashed rgba(125, 133, 144, 0.3);
          border-radius: 8px;
          padding: 0.75rem;
        }
        .goal-card {
          background: linear-gradient(180deg, rgba(28, 33, 40, 0.92), rgba(17, 22, 29, 0.96));
          border: 1px solid rgba(125, 133, 144, 0.2);
          border-left: 3px solid var(--muted);
          border-radius: 8px;
          padding: 0.8rem;
          min-width: 0;
        }
        .goal-card.priority-p1 { border-left-color: var(--yellow); }
        .goal-card.priority-p2 { border-left-color: var(--blue); }
        .goal-card.priority-p3 { border-left-color: var(--purple); }
        .goal-card.goal-done {
          border-left-color: var(--green);
          opacity: 0.86;
        }
        .goal-meta {
          display: flex;
          flex-wrap: wrap;
          gap: 0.35rem;
          margin-bottom: 0.45rem;
        }
        .goal-title {
          font-size: 0.82rem;
          color: var(--text);
          font-weight: 700;
          margin-bottom: 0.35rem;
        }
        .goal-summary {
          color: var(--text);
          opacity: 0.9;
          font-size: 0.75rem;
          margin-bottom: 0.55rem;
        }
        .goal-section {
          margin-top: 0.55rem;
        }
        .goal-section-label {
          color: var(--muted);
          font-size: 0.67rem;
          letter-spacing: 0.08em;
          text-transform: uppercase;
          margin-bottom: 0.25rem;
        }
        .chips {
          display: flex;
          flex-wrap: wrap;
          gap: 0.3rem;
        }
        .chip {
          font-size: 0.7rem;
          padding: 2px 7px;
          border-radius: 999px;
          border: 1px solid var(--border);
          background: rgba(13, 17, 23, 0.62);
          max-width: 100%;
          white-space: normal;
          overflow-wrap: anywhere;
        }
        .chip-area { color: var(--blue); border-color: rgba(88, 166, 255, 0.45); }
        .chip-priority { color: var(--yellow); border-color: rgba(210, 153, 34, 0.5); }
        .chip-host { color: var(--purple); border-color: rgba(188, 140, 255, 0.35); }
        .chip-service { color: var(--blue); border-color: rgba(88, 166, 255, 0.35); }
        .chip-block { color: var(--orange); border-color: rgba(240, 136, 62, 0.45); }
        .chip-unlock { color: var(--green); border-color: rgba(63, 185, 80, 0.45); }
        .chip-clickable {
          cursor: pointer;
          font: inherit;
          appearance: none;
        }
        .chip-clickable:hover {
          border-color: var(--blue);
          color: var(--blue);
        }
        .goal-context {
          display: grid;
          gap: 0.5rem;
        }
        .goal-docs {
          display: flex;
          flex-wrap: wrap;
          gap: 0.45rem;
          margin-top: 0.25rem;
          min-width: 0;
        }
        .goal-doc-link {
          color: var(--blue);
          text-decoration: none;
          font-size: 0.72rem;
        }
        .goal-doc-link:hover { text-decoration: underline; }

        /* Attention */
        .attention-list {
          display: flex;
          flex-direction: column;
          gap: 0.75rem;
        }
        .attention-item {
          background: rgba(12, 17, 23, 0.5);
          border: 1px solid rgba(125, 133, 144, 0.18);
          border-radius: 8px;
          padding: 0.8rem;
          min-width: 0;
        }
        .attention-item.severity-warn { border-left: 3px solid var(--yellow); }
        .attention-item.severity-note { border-left: 3px solid var(--blue); }
        .attention-head {
          display: flex;
          justify-content: space-between;
          gap: 0.5rem;
          margin-bottom: 0.35rem;
        }
        .attention-title { font-weight: 700; font-size: 0.8rem; }
        .attention-host { color: var(--muted); font-size: 0.72rem; }
        .attention-detail { color: var(--text); font-size: 0.74rem; opacity: 0.92; }
        .attention-empty {
          color: var(--muted);
          font-size: 0.8rem;
          padding: 0.6rem 0;
        }

        /* Health */
        .health-panel {
          margin-bottom: 1.25rem;
        }
        .health-summary {
          display: flex;
          flex-wrap: wrap;
          gap: 0.45rem;
          margin-bottom: 0.75rem;
        }
        .health-chip {
          font-size: 0.72rem;
          padding: 2px 8px;
          border-radius: 999px;
          border: 1px solid var(--border);
          background: rgba(13, 17, 23, 0.62);
          color: var(--muted);
        }
        .health-chip strong { color: var(--text); }
        .health-chip.good { color: var(--green); border-color: rgba(63, 185, 80, 0.45); }
        .health-chip.warn { color: var(--yellow); border-color: rgba(210, 153, 34, 0.45); }
        .health-chip.bad { color: var(--red); border-color: rgba(248, 81, 73, 0.45); }
        .health-list {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
          gap: 0.75rem;
        }
        .health-row {
          background: rgba(12, 17, 23, 0.5);
          border: 1px solid rgba(125, 133, 144, 0.18);
          border-radius: 8px;
          padding: 0.8rem;
          min-width: 0;
        }
        .health-row-top {
          display: flex;
          justify-content: space-between;
          gap: 0.5rem;
          align-items: baseline;
          margin-bottom: 0.4rem;
        }
        .health-host {
          font-size: 0.82rem;
          font-weight: 700;
          color: var(--blue);
        }
        .health-status {
          font-size: 0.68rem;
          padding: 1px 7px;
          border-radius: 999px;
          border: 1px solid;
          text-transform: uppercase;
          letter-spacing: 0.06em;
        }
        .health-status.pass {
          color: var(--green);
          border-color: rgba(63, 185, 80, 0.45);
        }
        .health-status.warn {
          color: var(--yellow);
          border-color: rgba(210, 153, 34, 0.45);
        }
        .health-row-meta {
          color: var(--muted);
          font-size: 0.74rem;
          margin-bottom: 0.55rem;
        }
        .health-failures {
          display: flex;
          flex-wrap: wrap;
          gap: 0.3rem;
        }
        .health-failure {
          color: var(--orange);
          border-color: rgba(240, 136, 62, 0.45);
          background: rgba(13, 17, 23, 0.6);
          font-size: 0.68rem;
          padding: 2px 7px;
          border-radius: 999px;
        }

        .command-list {
          display: flex;
          flex-direction: column;
          gap: 0.35rem;
          min-width: 0;
        }
        .command-chip {
          display: block;
          font-family: inherit;
          font-size: 0.7rem;
          color: var(--text);
          background: rgba(13, 17, 23, 0.76);
          border: 1px solid rgba(125, 133, 144, 0.2);
          border-radius: 6px;
          padding: 0.35rem 0.45rem;
          white-space: normal;
          overflow-wrap: anywhere;
          line-height: 1.35;
        }
        .command-chip code {
          font-family: inherit;
        }

        /* Host inventory */
        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(360px, 1fr)); gap: 1rem; }
        .card {
          background: linear-gradient(180deg, rgba(22, 27, 34, 0.95), rgba(17, 22, 29, 0.98));
          border: 1px solid var(--border);
          border-radius: 10px;
          padding: 1rem 1.25rem;
          min-width: 0;
        }
        .card.hidden { display: none; }
        .card.has-gaps { border-color: #6e3a1e; }
        .card-header {
          display: flex;
          align-items: baseline;
          gap: 0.5rem;
          margin-bottom: 0.75rem;
          border-bottom: 1px solid var(--border);
          padding-bottom: 0.5rem;
          flex-wrap: wrap;
        }
        .hostname { font-size: 1rem; font-weight: 600; color: var(--blue); }
        .badge {
          font-size: 0.7rem;
          padding: 1px 6px;
          border-radius: 10px;
          border: 1px solid;
        }
        .badge-deploy { color: var(--green); border-color: var(--green); }
        .badge-backup-critical { color: var(--yellow); border-color: var(--yellow); }
        .badge-backup-standard { color: var(--muted); border-color: var(--muted); }
        .badge-gap { color: var(--orange); border-color: var(--orange); }
        .badge-imperf { color: var(--purple); border-color: #7a5af855; }
        .meta-row { display: flex; justify-content: space-between; margin-bottom: 0.4rem; }
        .meta-label { color: var(--muted); }
        .meta-value { color: var(--text); }
        .section-title {
          font-size: 0.7rem;
          text-transform: uppercase;
          letter-spacing: 0.08em;
          color: var(--muted);
          margin: 0.75rem 0 0.4rem;
        }
        .tags { display: flex; flex-wrap: wrap; gap: 0.3rem; }
        .tag {
          font-size: 0.72rem;
          padding: 2px 7px;
          border-radius: 4px;
          background: #1c2128;
          border: 1px solid var(--border);
        }
        .tag-on { color: var(--green); border-color: #238636; }
        .tag-off { color: var(--muted); opacity: 0.5; }
        .tag-profile { color: var(--purple); border-color: #7a5af855; }
        .tag-port { color: var(--orange); border-color: #6e3a1e; }
        .tag-gap { color: var(--orange); border-color: #6e3a1e; }
        .tag-command {
          color: var(--blue);
          border-color: rgba(88, 166, 255, 0.4);
          background: rgba(13, 17, 23, 0.76);
        }

        footer { margin-top: 2rem; color: var(--muted); font-size: 0.8rem; }

        @media (max-width: 1180px) {
          .operator-row {
            grid-template-columns: 1fr;
          }
        }

        @media (max-width: 980px) {
          .goal-board {
            grid-template-columns: repeat(2, minmax(0, 1fr));
          }
        }

        @media (max-width: 720px) {
          body { padding: 1rem; }
          .goal-board {
            grid-template-columns: 1fr;
          }
          .summary,
          .panel,
          .card {
            border-radius: 8px;
          }
        }
      </style>
    </head>
    <body>
      <h1>NixOS Fleet Inventory</h1>
      <p class="subtitle">Generated from flake evaluation &bull; nix build '.#inventory'</p>

      <div class="summary" id="summary"></div>
      <div class="operator-row">
        <section class="panel">
          <div class="panel-header">
            <div>
              <div class="panel-title">Goals Board</div>
              <div class="panel-subtitle">Manual roadmap items, grouped by status and filtered by area.</div>
            </div>
            <div class="panel-actions">
              <button class="panel-action" id="toggleGoalsBtn" type="button">Collapse goals</button>
            </div>
          </div>
          <div id="goalSectionBody">
            <div class="filters" id="goalFilters"></div>
            <div class="goal-board" id="goalBoard"></div>
          </div>
        </section>
        <section class="panel">
          <div class="panel-header">
            <div>
              <div class="panel-title">Attention Needed</div>
              <div class="panel-subtitle">Computed findings from live host configuration. This is separate from the roadmap.</div>
            </div>
          </div>
          <div class="attention-list" id="attentionList"></div>
        </section>
      </div>
      <section class="panel health-panel">
        <div class="panel-header">
          <div>
            <div class="panel-title">Health Signals</div>
            <div class="panel-subtitle">Closure cost and invariant status derived from the current flake evaluation.</div>
          </div>
        </div>
        <div class="health-summary" id="healthSummary"></div>
        <div class="health-list" id="healthList"></div>
      </section>
      <div class="filters" id="filters"></div>
      <div class="grid" id="grid"></div>
      <footer id="footer"></footer>

      <script src="wave3-data.js"></script>
      <script>
        const data = ${dataJson};
        const hosts = data.hosts;
        const goals = data.goals;
        const wave3Data = window.__WAVE3_DATA__ || { hosts: { } };
        const hostByName = Object.fromEntries(hosts.map(host => [host.name, host]));
        const goalById = Object.fromEntries(goals.map(goal => [goal.id, goal]));
        const goalStatusOrder = ['now', 'blocked', 'next', 'later', 'done'];
        const goalStatusLabels = {
          now: 'Now',
          blocked: 'Blocked',
          next: 'Next',
          later: 'Later',
          done: 'Done',
        };
        const goalAreaLabels = {
          platform: 'Platform',
          homeserver: 'Homeserver',
          deploy: 'Deploy',
          backup: 'Backup',
          observability: 'Observability',
          security: 'Security',
        };
        const goalPriorityLabels = {
          p1: 'P1',
          p2: 'P2',
          p3: 'P3',
        };
        const goalPriorityOrder = {
          p1: 0,
          p2: 1,
          p3: 2,
        };
        const goalHostOrder = ['main', 'homeserver', 'homeserver-vm', 'vm'];
        const goalHostLabels = {
          main: 'main',
          homeserver: 'homeserver',
          'homeserver-vm': 'homeserver-vm',
          vm: 'vm',
        };
        const goalServiceLabels = {
          inventory: 'Inventory',
          'deploy-rs': 'deploy-rs',
          'github-actions': 'GitHub Actions',
          'smoke-tests': 'Smoke tests',
          restic: 'restic',
          b2: 'Backblaze B2',
          adguard: 'AdGuard Home',
          tailscale: 'Tailscale',
          lgtm: 'LGTM',
          grafana: 'Grafana',
          loki: 'Loki',
          prometheus: 'Prometheus',
          vaultwarden: 'Vaultwarden',
          syncthing: 'Syncthing',
          sops: 'SOPS',
          age: 'age',
          auditd: 'auditd',
          osquery: 'osquery',
          alloy: 'Alloy',
          nginx: 'Nginx',
          sandboxing: 'Sandboxing',
          checks: 'Checks',
        };
        const goalServiceOrder = Object.keys(goalServiceLabels);

        const svcLabels = {
          openssh: 'SSH', tailscale: 'Tailscale', firewall: 'Firewall',
          fail2ban: 'fail2ban', vaultwarden: 'Vaultwarden', syncthing: 'Syncthing',
          hyprland: 'Hyprland', observabilityStack: 'LGTM', observabilityClient: 'OTel',
          usbguard: 'USBGuard', lanzaboote: 'Lanzaboote',
        };

        const profileLabels = {
          desktop: 'Desktop', security: 'Security',
          observability: 'LGTM stack', observabilityClient: 'OTel client',
        };

        function humanBytes(bytes) {
          if (bytes == null) return 'unknown';
          if (bytes < 1024) return String(bytes) + ' B';
          const units = ['KiB', 'MiB', 'GiB', 'TiB'];
          let value = bytes / 1024;
          let unit = 'KiB';
          for (const next of units.slice(1)) {
            if (value < 1024) break;
            value /= 1024;
            unit = next;
          }
          return value.toFixed(value >= 10 ? 0 : 1) + ' ' + unit;
        }

        function wave3For(hostName) {
          return wave3Data.hosts?.[hostName] ?? null;
        }

        function healthResults(host) {
          return host.health?.invariantResults ?? [];
        }

        function healthCounts(host) {
          const results = healthResults(host);
          const failed = results.filter(result => !result.passed);
          return {
            total: results.length,
            passed: results.length - failed.length,
            failed: failed.length,
            failedResults: failed,
            status: failed.length === 0 ? 'pass' : 'warn',
          };
        }

        function securityGaps(h) {
          const gaps = [];
          if (h.services.openssh && !h.services.fail2ban) gaps.push('SSH w/o fail2ban');
          if (h.services.openssh && !h.services.firewall) gaps.push('SSH w/o firewall');
          if (h.services.tailscale && !h.services.firewall) gaps.push('Tailscale w/o firewall');
          if (h.name !== 'vm' && h.profiles.desktop && !h.services.usbguard) gaps.push('Desktop w/o USBGuard');
          return gaps;
        }

        function computeAttentionItems() {
          const items = [];

          for (const h of hosts) {
            for (const gap of securityGaps(h)) {
              items.push({
                host: h.name,
                severity: 'warn',
                title: 'Security gap',
                detail: gap,
              });
            }

            if (h.backupClass === 'critical' && !h.services.observabilityStack && !h.services.observabilityClient) {
              items.push({
                host: h.name,
                severity: 'note',
                title: 'Backup-critical without observability signal',
                detail: 'This host is marked backup-critical but has no LGTM stack or OTel client enabled.',
              });
            }
          }

          return items;
        }

        const attentionItems = computeAttentionItems();

        function el(tag, cls, text) {
          const e = document.createElement(tag);
          if (cls) e.className = cls;
          if (text !== undefined) e.textContent = text;
          return e;
        }

        function compareGoals(a, b) {
          const priority = (goalPriorityOrder[a.priority] ?? 99) - (goalPriorityOrder[b.priority] ?? 99);
          if (priority !== 0) return priority;
          return a.title.localeCompare(b.title);
        }

        function goalHosts(goal) {
          return goal.hosts ?? [];
        }

        function goalServices(goal) {
          return goal.services ?? [];
        }

        function goalCommands(goal) {
          const commands = [];
          const seen = new Set();
          const add = command => {
            if (!seen.has(command)) {
              seen.add(command);
              commands.push(command);
            }
          };

          for (const command of (goal.validate ?? [])) add(command);

          for (const hostName of goalHosts(goal)) {
            const host = hostByName[hostName];
            if (!host) continue;

            add(`nix build '.#nixosConfigurations.''${hostName}.config.system.build.toplevel'`);
            if (hostName === 'main') {
              add(`nh os switch --hostname main .`);
            } else if (hostName === 'homeserver-vm') {
              add(`nh os switch --hostname main .`);
            } else if (host.deployable) {
              add(`deploy '.#''${hostName}'`);
            }
          }

          return commands;
        }

        function hostCommands(host) {
          const commands = [`nix build '.#nixosConfigurations.''${host.name}.config.system.build.toplevel'`];
          if (host.name === 'main' || host.name === 'homeserver-vm') {
            commands.push(`nh os switch --hostname main .`);
          } else if (host.deployable) {
            commands.push(`deploy '.#''${host.name}'`);
          }
          return commands;
        }

        function goalRefTitle(goalId) {
          return goalById[goalId]?.title ?? goalId;
        }

        function buildGoalCard(goal) {
          const card = el('article', 'goal-card priority-' + goal.priority + (goal.status === 'done' ? ' goal-done' : ""));
          const blockedBy = goal.blockedBy ?? [];
          const unlocks = goal.unlocks ?? [];
          const docs = goal.docs ?? [];

          const meta = el('div', 'goal-meta');
          meta.appendChild(el('span', 'chip chip-area', goalAreaLabels[goal.area] ?? goal.area));
          meta.appendChild(el('span', 'chip chip-priority', goalPriorityLabels[goal.priority] ?? goal.priority));
          card.appendChild(meta);

          card.appendChild(el('div', 'goal-title', goal.title));
          card.appendChild(el('div', 'goal-summary', goal.summary));

          const context = el('div', 'goal-context');

          const hosts = goalHosts(goal);
          if (hosts.length) {
            const section = el('div', 'goal-section');
            section.appendChild(el('div', 'goal-section-label', 'Related Hosts'));
            const chips = el('div', 'chips');
            for (const host of hosts) {
              const btn = el('button', 'chip chip-host chip-clickable', goalHostLabels[host] ?? host);
              btn.addEventListener('click', () => {
                activeGoalHost = activeGoalHost === host ? null : host;
                buildGoalFilters();
                buildGoalBoard();
              });
              chips.appendChild(btn);
            }
            section.appendChild(chips);
            context.appendChild(section);
          }

          const services = goalServices(goal);
          if (services.length) {
            const section = el('div', 'goal-section');
            section.appendChild(el('div', 'goal-section-label', 'Related Services'));
            const chips = el('div', 'chips');
            for (const service of services) {
              const btn = el('button', 'chip chip-service chip-clickable', goalServiceLabels[service] ?? service);
              btn.addEventListener('click', () => {
                activeGoalService = activeGoalService === service ? null : service;
                buildGoalFilters();
                buildGoalBoard();
              });
              chips.appendChild(btn);
            }
            section.appendChild(chips);
            context.appendChild(section);
          }

          if (blockedBy.length) {
            const section = el('div', 'goal-section');
            section.appendChild(el('div', 'goal-section-label', 'Depends On'));
            const chips = el('div', 'chips');
            for (const blocker of blockedBy) chips.appendChild(el('span', 'chip chip-block', goalRefTitle(blocker)));
            section.appendChild(chips);
            context.appendChild(section);
          }

          if (unlocks.length) {
            const section = el('div', 'goal-section');
            section.appendChild(el('div', 'goal-section-label', 'Unlocks'));
            const chips = el('div', 'chips');
            for (const unlock of unlocks) chips.appendChild(el('span', 'chip chip-unlock', goalRefTitle(unlock)));
            section.appendChild(chips);
            context.appendChild(section);
          }

          const commands = goalCommands(goal);
          if (commands.length) {
            const section = el('div', 'goal-section');
            section.appendChild(el('div', 'goal-section-label', 'Validate'));
            const list = el('div', 'command-list');
            for (const command of commands) {
              const cmd = el('div', 'command-chip', command);
              list.appendChild(cmd);
            }
            section.appendChild(list);
            context.appendChild(section);
          }

          if (docs.length) {
            const section = el('div', 'goal-section');
            section.appendChild(el('div', 'goal-section-label', 'Docs'));
            const links = el('div', 'goal-docs');
            for (const doc of docs) {
              const link = el('a', 'goal-doc-link', doc.path);
              link.href = doc.url;
              link.target = '_blank';
              link.rel = 'noreferrer';
              links.appendChild(link);
            }
            section.appendChild(links);
            context.appendChild(section);
          }

          card.appendChild(context);

          return card;
        }

        let activeGoalStatus = null;
        let activeGoalArea = null;
        let activeGoalHost = null;
        let activeGoalService = null;
        let goalsCollapsed = false;

        function filteredGoals() {
          return goals.filter(goal => {
            const statusMatch = !activeGoalStatus || goal.status === activeGoalStatus;
            const areaMatch = !activeGoalArea || goal.area === activeGoalArea;
            const hostMatch = !activeGoalHost || goalHosts(goal).includes(activeGoalHost);
            const serviceMatch = !activeGoalService || goalServices(goal).includes(activeGoalService);
            return statusMatch && areaMatch && hostMatch && serviceMatch;
          });
        }

        function buildGoalBoard() {
          const filtered = filteredGoals();
          const board = document.getElementById('goalBoard');
          board.innerHTML = "";

          for (const status of goalStatusOrder) {
            const columnGoals = filtered
              .filter(goal => goal.status === status)
              .sort(compareGoals);

            const column = el('section', 'goal-column');
            const header = el('div', 'goal-column-header');
            header.appendChild(el('div', 'goal-column-title', goalStatusLabels[status]));
            header.appendChild(el('div', 'goal-column-count', String(columnGoals.length)));
            column.appendChild(header);

            if (!columnGoals.length) {
              column.appendChild(el('div', 'goal-empty', 'No matching goals.'));
            } else {
              const list = el('div', 'goal-list');
              for (const goal of columnGoals) list.appendChild(buildGoalCard(goal));
              column.appendChild(list);
            }

            board.appendChild(column);
          }
        }

        function buildGoalFilters() {
          const bar = document.getElementById('goalFilters');
          bar.innerHTML = "";
          bar.appendChild(el('span', 'filter-label', 'Filter goals:'));

          const mkButton = (label, kind, value, isActive, onClick) => {
            const btn = el('button', 'filter-btn' + (isActive ? ' active' : ""), label);
            btn.dataset.kind = kind;
            btn.dataset.value = value ?? "";
            btn.addEventListener('click', onClick);
            return btn;
          };

          bar.appendChild(mkButton('All', 'status', "", activeGoalStatus === null, () => {
            activeGoalStatus = null;
            buildGoalFilters();
            buildGoalBoard();
          }));

          for (const status of goalStatusOrder) {
            bar.appendChild(mkButton(goalStatusLabels[status], 'status', status, activeGoalStatus === status, () => {
              activeGoalStatus = activeGoalStatus === status ? null : status;
              buildGoalFilters();
              buildGoalBoard();
            }));
          }

          bar.appendChild(el('span', 'filter-group-label', 'Area'));
          bar.appendChild(mkButton('All areas', 'area', "", activeGoalArea === null, () => {
            activeGoalArea = null;
            buildGoalFilters();
            buildGoalBoard();
          }));

          for (const area of Object.keys(goalAreaLabels)) {
            bar.appendChild(mkButton(goalAreaLabels[area], 'area', area, activeGoalArea === area, () => {
              activeGoalArea = activeGoalArea === area ? null : area;
              buildGoalFilters();
              buildGoalBoard();
            }));
          }

          const moreFilters = el('details', 'filter-details');
          moreFilters.open = activeGoalHost !== null || activeGoalService !== null;
          const summary = el('summary', 'filter-summary', 'More filters');
          moreFilters.appendChild(summary);
          const body = el('div', 'filter-details-body');

          body.appendChild(el('span', 'filter-group-label', 'Hosts'));
          body.appendChild(mkButton('All hosts', 'host', "", activeGoalHost === null, () => {
            activeGoalHost = null;
            buildGoalFilters();
            buildGoalBoard();
          }));

          for (const host of goalHostOrder) {
            if (!goals.some(goal => goalHosts(goal).includes(host))) continue;
            body.appendChild(mkButton(goalHostLabels[host] ?? host, 'host', host, activeGoalHost === host, () => {
              activeGoalHost = activeGoalHost === host ? null : host;
              buildGoalFilters();
              buildGoalBoard();
            }));
          }

          body.appendChild(el('span', 'filter-group-label', 'Services'));
          body.appendChild(mkButton('All services', 'service', "", activeGoalService === null, () => {
            activeGoalService = null;
            buildGoalFilters();
            buildGoalBoard();
          }));

          for (const service of goalServiceOrder) {
            if (!goals.some(goal => goalServices(goal).includes(service))) continue;
            body.appendChild(mkButton(goalServiceLabels[service] ?? service, 'service', service, activeGoalService === service, () => {
              activeGoalService = activeGoalService === service ? null : service;
              buildGoalFilters();
              buildGoalBoard();
            }));
          }

          moreFilters.appendChild(body);
          bar.appendChild(moreFilters);
        }

        function buildAttentionPanel() {
          const container = document.getElementById('attentionList');
          container.innerHTML = "";

          if (!attentionItems.length) {
            container.appendChild(el('div', 'attention-empty', 'No computed attention items.'));
            return;
          }

          for (const item of attentionItems) {
            const card = el('article', 'attention-item severity-' + item.severity);
            const head = el('div', 'attention-head');
            head.appendChild(el('div', 'attention-title', item.title));
            head.appendChild(el('div', 'attention-host', item.host));
            card.appendChild(head);
            card.appendChild(el('div', 'attention-detail', item.detail));
            container.appendChild(card);
          }
        }

        function setGoalsCollapsed(collapsed) {
          goalsCollapsed = collapsed;
          const body = document.getElementById('goalSectionBody');
          const button = document.getElementById('toggleGoalsBtn');
          body.hidden = goalsCollapsed;
          button.textContent = goalsCollapsed ? 'Expand goals' : 'Collapse goals';
          button.classList.toggle('active', goalsCollapsed);
        }

        function buildCard(h) {
          const gaps = securityGaps(h);
          const card = el('div', 'card' + (gaps.length ? ' has-gaps' : ""));
          card._host = h;

          // Header
          const header = el('div', 'card-header');
          header.appendChild(el('span', 'hostname', h.name));
          if (h.deployable) header.appendChild(el('span', 'badge badge-deploy', 'deploy-rs'));
          if (h.backupClass === 'critical') header.appendChild(el('span', 'badge badge-backup-critical', 'backup:critical'));
          if (h.backupClass === 'standard') header.appendChild(el('span', 'badge badge-backup-standard', 'backup:standard'));
          if (h.impermanence) header.appendChild(el('span', 'badge badge-imperf', 'impermanence'));
          if (gaps.length) header.appendChild(el('span', 'badge badge-gap', gaps.length + ' gap' + (gaps.length > 1 ? 's' : "")));
          card.appendChild(header);

          // Meta rows
          const metaRows = [
            ['system', h.system],
            ['stateVersion', h.stateVersion],
            h.tailscaleTag ? ['tailscale tag', h.tailscaleTag] : null,
            h.tailnetFQDN  ? ['tailnet FQDN', h.tailnetFQDN] : null,
            h.ip           ? ['ip', h.ip] : null,
            h.homeManagerRole ? ['home-manager', h.homeManagerRole + (h.homeManagerProfiles.length ? ' + ' + h.homeManagerProfiles.join(', ') : "")] : null,
          ].filter(Boolean);

          for (const [label, value] of metaRows) {
            const row = el('div', 'meta-row');
            row.appendChild(el('span', 'meta-label', label));
            row.appendChild(el('span', 'meta-value', value));
            card.appendChild(row);
          }

          const wave3 = wave3For(h.name);
          if (wave3?.closureSizeBytes != null) {
            const row = el('div', 'meta-row');
            row.appendChild(el('span', 'meta-label', 'closure'));
            row.appendChild(el('span', 'meta-value', humanBytes(wave3.closureSizeBytes)));
            card.appendChild(row);
          }

          const health = healthCounts(h);
          if (health.total > 0) {
            const row = el('div', 'meta-row');
            row.appendChild(el('span', 'meta-label', 'invariants'));
            const value = el('span', 'meta-value');
            const badge = el('span', 'health-status ' + health.status, health.passed + '/' + health.total + ' pass');
            value.appendChild(badge);
            row.appendChild(value);
            card.appendChild(row);
          }

          const commands = hostCommands(h);
          if (commands.length) {
            card.appendChild(el('div', 'section-title', 'Validate'));
            const validateList = el('div', 'command-list');
            for (const command of commands) validateList.appendChild(el('div', 'command-chip', command));
            card.appendChild(validateList);
          }

          // Profiles
          const activeProfiles = Object.entries(h.profiles).filter(([, v]) => v).map(([k]) => profileLabels[k] ?? k);
          if (activeProfiles.length) {
            card.appendChild(el('div', 'section-title', 'Profiles'));
            const ptags = el('div', 'tags');
            for (const p of activeProfiles) ptags.appendChild(el('span', 'tag tag-profile', p));
            card.appendChild(ptags);
          }

          // Services
          card.appendChild(el('div', 'section-title', 'Services'));
          const svcs = el('div', 'tags');
          for (const [key, enabled] of Object.entries(h.services)) {
            svcs.appendChild(el('span', 'tag ' + (enabled ? 'tag-on' : 'tag-off'), svcLabels[key] ?? key));
          }
          card.appendChild(svcs);

          // Open ports
          const allPorts = [
            ...h.openTCPPorts.map(p => 'TCP/' + p),
            ...h.openUDPPorts.map(p => 'UDP/' + p),
          ];
          if (allPorts.length) {
            card.appendChild(el('div', 'section-title', 'Open Ports'));
            const portTags = el('div', 'tags');
            for (const p of allPorts) portTags.appendChild(el('span', 'tag tag-port', p));
            card.appendChild(portTags);
          }

          // Security gaps
          if (gaps.length) {
            card.appendChild(el('div', 'section-title', 'Security Gaps'));
            const gapTags = el('div', 'tags');
            for (const g of gaps) gapTags.appendChild(el('span', 'tag tag-gap', g));
            card.appendChild(gapTags);
          }

          return card;
        }

        function buildHealthPanel() {
          const baseline = wave3For('main')?.closureSizeBytes ?? null;
          const rows = hosts
            .map(host => ({
              host,
              wave3: wave3For(host.name),
              health: healthCounts(host),
            }))
            .sort((a, b) => (b.wave3?.closureSizeBytes ?? 0) - (a.wave3?.closureSizeBytes ?? 0));

          const list = document.getElementById('healthList');
          list.innerHTML = "";

          for (const rowData of rows) {
            const { host, wave3, health } = rowData;
            const row = el('article', 'health-row');
            const top = el('div', 'health-row-top');
            top.appendChild(el('span', 'health-host', host.name));
            top.appendChild(
              el(
                'span',
                'health-status ' + health.status,
                health.failed ? health.failed + ' fail' : health.passed + '/' + health.total + ' pass'
              )
            );
            row.appendChild(top);

            const metrics = [];
            if (wave3?.closureSizeBytes != null) {
              metrics.push('closure ' + humanBytes(wave3.closureSizeBytes));
              if (baseline != null && host.name !== 'main') {
                const delta = wave3.closureSizeBytes - baseline;
                const sign = delta >= 0 ? '+' : '-';
                metrics.push(sign + humanBytes(Math.abs(delta)) + ' vs main');
              }
            }
            if (health.total > 0) {
              metrics.push(health.passed + '/' + health.total + ' invariants pass');
            }

            row.appendChild(el('div', 'health-row-meta', metrics.join(' • ')));

            if (health.failedResults.length) {
              const failures = el('div', 'health-failures');
              for (const result of health.failedResults) {
                failures.appendChild(el('span', 'health-failure', result.name));
              }
              row.appendChild(failures);
            }

            list.appendChild(row);
          }

          const summary = document.getElementById('healthSummary');
          const totalClosure = rows.reduce((sum, row) => sum + (row.wave3?.closureSizeBytes ?? 0), 0);
          const largest = rows[0] || null;
          const failingHosts = rows.filter(row => row.health.failed > 0);
          const failingChecks = rows.reduce((sum, row) => sum + row.health.failed, 0);
          const chips = [
            ['closure total', humanBytes(totalClosure), 'good'],
            [
              'largest host',
              largest ? largest.host.name + ' (' + humanBytes(largest.wave3?.closureSizeBytes ?? 0) + ')' : 'n/a',
              'good',
            ],
            ['failing hosts', String(failingHosts.length), failingHosts.length > 0 ? 'warn' : 'good'],
            ['failing checks', String(failingChecks), failingChecks > 0 ? 'bad' : 'good'],
          ];

          summary.innerHTML = "";
          for (const [label, value, tone] of chips) {
            const chip = el('span', 'health-chip ' + tone);
            chip.appendChild(el('strong', null, label + ': '));
            chip.appendChild(document.createTextNode(value));
            summary.appendChild(chip);
          }
        }

        function buildSummary() {
          const deployCount = hosts.filter(h => h.deployable).length;
          const critBackup  = hosts.filter(h => h.backupClass === 'critical').length;
          const tsCount     = hosts.filter(h => h.services.tailscale).length;
          const gapCount    = hosts.filter(h => securityGaps(h).length > 0).length;
          const imperfCount = hosts.filter(h => h.impermanence).length;
          const nowGoals    = goals.filter(g => g.status === 'now').length;
          const blockedGoals = goals.filter(g => g.status === 'blocked').length;
          const wave3Rows = hosts.map(h => wave3For(h.name)).filter(Boolean);
          const totalClosure = wave3Rows.reduce((sum, entry) => sum + (entry.closureSizeBytes ?? 0), 0);
          const largest = hosts
            .map(h => ({ host: h, wave3: wave3For(h.name) }))
            .sort((a, b) => (b.wave3?.closureSizeBytes ?? 0) - (a.wave3?.closureSizeBytes ?? 0))[0];
          const failingHosts = hosts.filter(h => healthCounts(h).failed > 0).length;

          const stats = [
            { value: hosts.length,  label: 'hosts' },
            { value: deployCount,   label: 'deploy-rs' },
            { value: tsCount,       label: 'on Tailscale' },
            { value: critBackup,    label: 'backup:critical' },
            { value: imperfCount,   label: 'impermanence' },
            { value: gapCount,      label: 'security gaps', warn: gapCount > 0 },
            { value: goals.length,  label: 'tracked goals' },
            { value: nowGoals,      label: 'goals:now' },
            { value: blockedGoals,  label: 'goals:blocked', warn: blockedGoals > 0 },
            { value: attentionItems.length, label: 'attention items', warn: attentionItems.length > 0 },
            { value: humanBytes(totalClosure), label: 'closure total' },
            { value: largest ? humanBytes(largest.wave3?.closureSizeBytes ?? 0) : 'n/a', label: 'largest closure' },
            { value: failingHosts, label: 'hosts w/ failed invariants', warn: failingHosts > 0 },
          ];

          const summary = document.getElementById('summary');
          summary.innerHTML = "";
          for (const s of stats) {
            const stat = el('div', 'stat' + (s.warn ? ' stat-warn' : ""));
            stat.appendChild(el('span', 'stat-value', String(s.value)));
            stat.appendChild(el('span', 'stat-label', s.label));
            summary.appendChild(stat);
          }
        }

        let activeFilter = null;

        function applyFilter() {
          document.querySelectorAll('.card').forEach(card => {
            const show = !activeFilter || activeFilter(card._host);
            card.classList.toggle('hidden', !show);
          });
          document.querySelectorAll('.filter-btn').forEach(btn => {
            btn.classList.toggle('active', btn._filter === activeFilter);
          });
        }

        function buildFilters() {
          const bar = document.getElementById('filters');
          bar.innerHTML = "";
          bar.appendChild(el('span', 'filter-label', 'Filter hosts:'));

          const filters = [
            { label: 'All',             fn: null },
            { label: 'deploy-rs',       fn: h => h.deployable },
            { label: 'Tailscale',       fn: h => h.services.tailscale },
            { label: 'backup:critical', fn: h => h.backupClass === 'critical' },
            { label: 'Impermanence',    fn: h => h.impermanence },
            { label: 'Has gaps',        fn: h => securityGaps(h).length > 0 },
            { label: 'Desktop',         fn: h => h.profiles.desktop },
            { label: 'LGTM',            fn: h => h.services.observabilityStack },
          ];

          for (const f of filters) {
            const btn = el('button', 'filter-btn' + (f.fn === null ? ' active' : ""), f.label);
            btn._filter = f.fn;
            btn.addEventListener('click', () => {
              activeFilter = (activeFilter === f.fn && f.fn !== null) ? null : f.fn;
              if (f.fn === null) activeFilter = null;
              applyFilter();
            });
            bar.appendChild(btn);
          }
        }

        buildSummary();
        buildHealthPanel();
        buildGoalFilters();
        buildGoalBoard();
        buildAttentionPanel();
        buildFilters();
        setGoalsCollapsed(false);

        document.getElementById('toggleGoalsBtn').addEventListener('click', () => {
          setGoalsCollapsed(!goalsCollapsed);
        });

        const grid = document.getElementById('grid');
        for (const h of hosts) grid.appendChild(buildCard(h));

        document.getElementById('footer').textContent =
          'Hosts: ' + hosts.length + ' \u2022 Goals: ' + goals.length + ' \u2022 Built from flake.nix \u2022 ' + hosts.map(h => h.name).join(', ') + ' \u2022 ' + data.repository;
      </script>
    </body>
    </html>
  '';
in
pkgs.runCommand "inventory"
  {
    nativeBuildInputs = [ pkgs.nix ];
    passAsFile = [
      "html"
      "hostSpec"
    ];
    inherit html;
    inherit hostSpec;
  }
  ''
    mkdir -p $out
    {
      echo 'window.__WAVE3_DATA__ = { hosts: {'
      while IFS=$'\t' read -r hostName closurePath || [ -n "$hostName" ]; do
        [ -n "$hostName" ] || continue
        if closureInfo="$(nix path-info -S "$closurePath" 2>/dev/null)"; then
          closureBytes="$(printf '%s\n' "$closureInfo" | awk '{print $2}')"
          echo "  \"''${hostName}\": { \"closureSizeBytes\": ''${closureBytes} },"
        else
          echo "  \"''${hostName}\": { \"closureSizeBytes\": null },"
        fi
      done < "$hostSpecPath"
      echo '} };'
    } > "$out/wave3-data.js"
    cp "$htmlPath" "$out/index.html"
  ''
