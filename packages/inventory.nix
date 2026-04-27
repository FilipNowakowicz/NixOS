{
  lib,
  pkgs,
  hostRegistry,
  allNixosConfigs,
}:
let
  extractHost =
    name: cfg:
    let
      meta = hostRegistry.${name};
      c = cfg.config;
    in
    {
      inherit name;
      inherit (meta) system;
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
    };

  hostsData = lib.mapAttrsToList extractHost allNixosConfigs;

  dataJson = builtins.toJSON hostsData;
  goalsJson = builtins.toJSON (builtins.readFile ../docs/goals.md);
  ideasJson = builtins.toJSON (builtins.readFile ../docs/ideas.md);

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
          background: var(--bg);
          color: var(--text);
          font-family: 'Cascadia Code', 'Fira Code', 'JetBrains Mono', monospace;
          font-size: 13px;
          padding: 2rem;
          line-height: 1.5;
        }
        h1 { font-size: 1.4rem; color: var(--blue); margin-bottom: 0.25rem; }
        .subtitle { color: var(--muted); font-size: 0.85rem; margin-bottom: 1.25rem; }

        /* ── Summary strip ── */
        .summary {
          display: flex;
          flex-wrap: wrap;
          gap: 1.5rem;
          background: var(--surface);
          border: 1px solid var(--border);
          border-radius: 6px;
          padding: 0.75rem 1.25rem;
          margin-bottom: 1.25rem;
          font-size: 0.8rem;
        }
        .stat { display: flex; flex-direction: column; }
        .stat-value { font-size: 1.3rem; font-weight: 600; color: var(--text); line-height: 1.2; }
        .stat-label { color: var(--muted); font-size: 0.72rem; }
        .stat-warn .stat-value { color: var(--yellow); }

        /* ── Filter bar ── */
        .filters {
          display: flex;
          flex-wrap: wrap;
          gap: 0.4rem;
          margin-bottom: 1.25rem;
          align-items: center;
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

        /* ── Grid ── */
        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(360px, 1fr)); gap: 1rem; }
        .card {
          background: var(--surface);
          border: 1px solid var(--border);
          border-radius: 6px;
          padding: 1rem 1.25rem;
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

        /* ── Goals panel ── */
        .goals-section {
          margin-top: 2rem;
          background: var(--surface);
          border: 1px solid var(--border);
          border-radius: 6px;
          overflow: hidden;
        }
        .goals-toggle {
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 0.65rem 1.25rem;
          cursor: pointer;
          border: none;
          background: none;
          width: 100%;
          color: var(--text);
          font-family: inherit;
          font-size: 0.85rem;
          font-weight: 600;
          border-bottom: 1px solid var(--border);
        }
        .goals-toggle:hover { background: #1c2128; }
        .goals-toggle .arrow { color: var(--muted); font-size: 0.7rem; transition: transform 0.2s; }
        .goals-toggle.collapsed .arrow { transform: rotate(-90deg); }
        .goals-body { padding: 1rem 1.5rem; display: grid; grid-template-columns: repeat(auto-fill, minmax(480px, 1fr)); gap: 0 2rem; }
        .goals-body.hidden { display: none; }
        .md-h2 { font-size: 0.85rem; font-weight: 600; color: var(--blue); margin: 1rem 0 0.4rem; }
        .md-h3 { font-size: 0.78rem; font-weight: 600; color: var(--purple); margin: 0.75rem 0 0.3rem; }
        .md-hr { border: none; border-top: 1px solid var(--border); margin: 0.5rem 0; grid-column: 1 / -1; }
        .md-todo { display: flex; gap: 0.5rem; align-items: baseline; margin: 0.2rem 0; font-size: 0.78rem; }
        .md-todo input[type=checkbox] { accent-color: var(--green); flex-shrink: 0; margin-top: 2px; pointer-events: none; }
        .md-todo.done { color: var(--muted); text-decoration: line-through; }
        .md-bullet { font-size: 0.78rem; margin: 0.2rem 0 0.2rem 1rem; color: var(--muted); }
        .md-bullet::before { content: "•"; margin-right: 0.4rem; }
        .md-p { font-size: 0.78rem; color: var(--muted); margin: 0.2rem 0; }

        footer { margin-top: 2rem; color: var(--muted); font-size: 0.8rem; }
      </style>
    </head>
    <body>
      <h1>NixOS Fleet Inventory</h1>
      <p class="subtitle">Generated from flake evaluation &bull; nix build '.#inventory'</p>

      <div class="summary" id="summary"></div>
      <div class="filters" id="filters"></div>
      <div class="grid" id="grid"></div>
      <div class="goals-section" id="goals-panel"></div>
      <div class="goals-section" id="ideas-panel"></div>
      <footer id="footer"></footer>

      <script>
        const hosts = ${dataJson};
        const goalsText = ${goalsJson};
        const ideasText = ${ideasJson};

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

        function securityGaps(h) {
          const gaps = [];
          if (h.services.openssh && !h.services.fail2ban) gaps.push('SSH w/o fail2ban');
          if (h.services.openssh && !h.services.firewall) gaps.push('SSH w/o firewall');
          if (h.services.tailscale && !h.services.firewall) gaps.push('Tailscale w/o firewall');
          if (h.profiles.desktop && !h.services.usbguard) gaps.push('Desktop w/o USBGuard');
          return gaps;
        }

        function el(tag, cls, text) {
          const e = document.createElement(tag);
          if (cls) e.className = cls;
          if (text !== undefined) e.textContent = text;
          return e;
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

        // ── Summary strip ──────────────────────────────────────────────────
        function buildSummary() {
          const deployCount = hosts.filter(h => h.deployable).length;
          const critBackup  = hosts.filter(h => h.backupClass === 'critical').length;
          const tsCount     = hosts.filter(h => h.services.tailscale).length;
          const gapCount    = hosts.filter(h => securityGaps(h).length > 0).length;
          const imperfCount = hosts.filter(h => h.impermanence).length;

          const stats = [
            { value: hosts.length,  label: 'hosts' },
            { value: deployCount,   label: 'deploy-rs' },
            { value: tsCount,       label: 'on Tailscale' },
            { value: critBackup,    label: 'backup:critical' },
            { value: imperfCount,   label: 'impermanence' },
            { value: gapCount,      label: 'security gaps', warn: gapCount > 0 },
          ];

          const summary = document.getElementById('summary');
          for (const s of stats) {
            const stat = el('div', 'stat' + (s.warn ? ' stat-warn' : ""));
            stat.appendChild(el('span', 'stat-value', String(s.value)));
            stat.appendChild(el('span', 'stat-label', s.label));
            summary.appendChild(stat);
          }
        }

        // ── Filter bar ────────────────────────────────────────────────────
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
          bar.appendChild(el('span', 'filter-label', 'Filter:'));

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

        // ── Goals panels ──────────────────────────────────────────────────
        function renderMarkdown(text) {
          const frag = document.createDocumentFragment();
          for (const rawLine of text.split('\n')) {
            const line = rawLine.trimEnd();
            let node;
            if (/^## /.test(line)) {
              node = el('div', 'md-h2', line.slice(3));
            } else if (/^### /.test(line)) {
              node = el('div', 'md-h3', line.slice(4));
            } else if (/^---$/.test(line)) {
              node = document.createElement('hr');
              node.className = 'md-hr';
            } else if (/^- \[x\] /i.test(line)) {
              node = el('div', 'md-todo done');
              const cb = document.createElement('input');
              cb.type = 'checkbox';
              cb.checked = true;
              node.appendChild(cb);
              node.appendChild(document.createTextNode(line.slice(6)));
            } else if (/^- \[ \] /.test(line)) {
              node = el('div', 'md-todo');
              const cb = document.createElement('input');
              cb.type = 'checkbox';
              node.appendChild(cb);
              node.appendChild(document.createTextNode(line.slice(6)));
            } else if (/^- /.test(line)) {
              node = el('div', 'md-bullet', line.slice(2));
            } else if (line.trim()) {
              node = el('div', 'md-p', line);
            } else {
              continue;
            }
            frag.appendChild(node);
          }
          return frag;
        }

        function buildGoalsPanel(id, title, text, startOpen) {
          const panel = document.getElementById(id);
          const toggle = document.createElement('button');
          toggle.className = 'goals-toggle' + (startOpen ? "" : ' collapsed');
          toggle.appendChild(el('span', null, title));
          const arrow = el('span', 'arrow', '\u25be');
          toggle.appendChild(arrow);
          panel.appendChild(toggle);

          const body = el('div', 'goals-body' + (startOpen ? "" : ' hidden'));
          body.appendChild(renderMarkdown(text));
          panel.appendChild(body);

          toggle.addEventListener('click', () => {
            const open = !body.classList.contains('hidden');
            body.classList.toggle('hidden', open);
            toggle.classList.toggle('collapsed', open);
          });
        }

        // ── Render ────────────────────────────────────────────────────────
        buildSummary();
        buildFilters();

        const grid = document.getElementById('grid');
        for (const h of hosts) grid.appendChild(buildCard(h));

        buildGoalsPanel('goals-panel', 'Roadmap & Goals', goalsText, true);
        buildGoalsPanel('ideas-panel', 'Ideas & Backlog', ideasText, false);

        document.getElementById('footer').textContent =
          'Hosts: ' + hosts.length + ' \u2022 Built from flake.nix \u2022 ' + hosts.map(h => h.name).join(', ');
      </script>
    </body>
    </html>
  '';
in
pkgs.runCommand "inventory"
  {
    passAsFile = [ "html" ];
    inherit html;
  }
  ''
    mkdir -p $out
    cp "$htmlPath" "$out/index.html"
  ''
