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

        /* ── Goals & Ideas panel ── */
        .gi-panel {
          margin-top: 2rem;
          background: var(--surface);
          border: 1px solid var(--border);
          border-radius: 6px;
          overflow: hidden;
        }
        .gi-panel-toggle {
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 0.65rem 1.25rem;
          cursor: pointer;
          border: none;
          border-bottom: 1px solid var(--border);
          background: none;
          width: 100%;
          color: var(--text);
          font-family: inherit;
          font-size: 0.85rem;
          font-weight: 600;
        }
        .gi-panel-toggle:hover { background: #1c2128; }
        .gi-panel-body { padding: 0 1.25rem 1rem; }
        .gi-panel-body.hidden { display: none; }
        .gi-section { margin-top: 1rem; }
        .gi-section-toggle {
          display: flex;
          align-items: center;
          justify-content: space-between;
          width: 100%;
          border: none;
          background: none;
          font-family: inherit;
          font-size: 0.78rem;
          font-weight: 600;
          color: var(--blue);
          cursor: pointer;
          padding: 0.3rem 0;
          border-bottom: 1px solid var(--border);
          margin-bottom: 0.4rem;
        }
        .gi-section-toggle:hover { color: var(--text); }
        .gi-section-body.hidden { display: none; }
        .gi-group-label {
          font-size: 0.7rem;
          text-transform: uppercase;
          letter-spacing: 0.07em;
          color: var(--purple);
          margin: 0.75rem 0 0.3rem 0.5rem;
        }
        .gi-item {
          border: 1px solid transparent;
          border-radius: 4px;
          margin: 0.2rem 0;
        }
        .gi-item-toggle {
          display: flex;
          align-items: baseline;
          gap: 0.5rem;
          width: 100%;
          border: none;
          background: none;
          font-family: inherit;
          font-size: 0.78rem;
          color: var(--text);
          cursor: pointer;
          padding: 0.3rem 0.5rem;
          text-align: left;
        }
        .gi-item-toggle:hover { background: #1c2128; border-radius: 4px; }
        .gi-item-toggle input[type=checkbox] { accent-color: var(--green); flex-shrink: 0; pointer-events: none; }
        .gi-item-toggle.done { color: var(--muted); text-decoration: line-through; }
        .gi-item-toggle .gi-arrow { color: var(--muted); font-size: 0.65rem; flex-shrink: 0; transition: transform 0.15s; margin-left: auto; padding-left: 0.5rem; }
        .gi-item-toggle.open .gi-arrow { transform: rotate(90deg); }
        .gi-item-body {
          font-size: 0.75rem;
          color: var(--muted);
          padding: 0.3rem 0.75rem 0.5rem 2rem;
          line-height: 1.6;
        }
        .gi-item-body.hidden { display: none; }
        .gi-num { color: var(--muted); flex-shrink: 0; }

        footer { margin-top: 2rem; color: var(--muted); font-size: 0.8rem; }
      </style>
    </head>
    <body>
      <h1>NixOS Fleet Inventory</h1>
      <p class="subtitle">Generated from flake evaluation &bull; nix build '.#inventory'</p>

      <div class="summary" id="summary"></div>
      <div class="filters" id="filters"></div>
      <div class="grid" id="grid"></div>
      <div class="gi-panel" id="gi-panel"></div>
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

        // ── Goals & Ideas panel ───────────────────────────────────────────

        function stripBold(s) {
          return s.replace(/\*\*([^*]+)\*\*/g, '$1');
        }

        function parseGoals(text) {
          const sections = [];
          let section = null, group = null, item = null;
          for (const raw of text.split('\n')) {
            const line = raw.trimEnd();
            if (/^## /.test(line)) {
              section = { label: line.slice(3), groups: [] };
              sections.push(section);
              group = null; item = null;
            } else if (/^### /.test(line) && section) {
              group = { label: line.slice(4), items: [] };
              section.groups.push(group);
              item = null;
            } else if (/^- \[[ x]\] /i.test(line) && section) {
              if (!group) { group = { label: null, items: [] }; section.groups.push(group); }
              const done = line[3].toLowerCase() === 'x';
              const rest = line.slice(6);
              const m = rest.match(/^\*\*([^*]+)\*\*\s*(?:—\s*)?(.*)$/);
              const title = m ? m[1] : rest.split(' — ')[0];
              const desc = m ? m[2].trim() : rest.split(' — ').slice(1).join(' — ').trim();
              item = { done, title, desc };
              group.items.push(item);
            } else if (item && line.trim() && !/^[#-]/.test(line)) {
              item.desc += (item.desc ? ' ' : "") + stripBold(line.trim());
            }
          }
          return sections.filter(s => s.groups.some(g => g.items.length > 0));
        }

        function parseIdeas(text) {
          const items = [];
          let item = null;
          for (const raw of text.split('\n')) {
            const line = raw.trimEnd();
            const m = line.match(/^(\d+)\.\s+(.+)/);
            if (m) {
              item = { num: m[1], title: m[2], desc: "" };
              items.push(item);
            } else if (item && line.trim()) {
              item.desc += (item.desc ? ' ' : "") + line.trim();
            }
          }
          return items;
        }

        function makeToggle(cls, label, startOpen) {
          const btn = document.createElement('button');
          btn.className = cls;
          btn.appendChild(el('span', null, label));
          btn.appendChild(el('span', 'gi-arrow', '\u25b6'));
          if (startOpen) btn.classList.add('open');
          return btn;
        }

        function wireToggle(btn, body) {
          btn.addEventListener('click', () => {
            const open = btn.classList.toggle('open');
            body.classList.toggle('hidden', !open);
          });
        }

        function buildAccordionItem(title, desc, done, prefix) {
          const item = el('div', 'gi-item');
          const toggle = document.createElement('button');
          toggle.className = 'gi-item-toggle' + (done ? ' done' : "");
          if (prefix !== undefined) {
            const cb = document.createElement('input');
            cb.type = 'checkbox';
            cb.checked = done;
            toggle.appendChild(cb);
          } else {
            toggle.appendChild(el('span', 'gi-num', prefix));
          }
          toggle.appendChild(document.createTextNode(title));
          toggle.appendChild(el('span', 'gi-arrow', '\u25b6'));
          item.appendChild(toggle);
          const body = el('div', 'gi-item-body hidden', desc || 'No description.');
          item.appendChild(body);
          wireToggle(toggle, body);
          return item;
        }

        function buildGIPanel() {
          const panel = document.getElementById('gi-panel');

          const panelToggle = makeToggle('gi-panel-toggle', 'Goals & Ideas', true);
          panel.appendChild(panelToggle);
          const panelBody = el('div', 'gi-panel-body');
          panel.appendChild(panelBody);
          wireToggle(panelToggle, panelBody);

          // ── Homeserver Roadmap (from goals.md) ──
          const goalSections = parseGoals(goalsText);
          const roadmapSection = el('div', 'gi-section');
          const roadmapToggle = makeToggle('gi-section-toggle', 'Homeserver Roadmap', true);
          roadmapSection.appendChild(roadmapToggle);
          const roadmapBody = el('div', 'gi-section-body');
          roadmapSection.appendChild(roadmapBody);
          wireToggle(roadmapToggle, roadmapBody);

          for (const sec of goalSections) {
            for (const group of sec.groups) {
              if (group.label) roadmapBody.appendChild(el('div', 'gi-group-label', group.label));
              for (const it of group.items) {
                roadmapBody.appendChild(buildAccordionItem(it.title, it.desc, it.done, undefined));
              }
            }
          }
          panelBody.appendChild(roadmapSection);

          // ── Ideas (from ideas.md) ──
          const ideas = parseIdeas(ideasText);
          const ideasSection = el('div', 'gi-section');
          const ideasToggle = makeToggle('gi-section-toggle', 'Ideas', false);
          ideasSection.appendChild(ideasToggle);
          const ideasBody = el('div', 'gi-section-body hidden');
          ideasSection.appendChild(ideasBody);
          wireToggle(ideasToggle, ideasBody);

          for (const it of ideas) {
            ideasBody.appendChild(buildAccordionItem(it.title, it.desc, false, it.num + '.'));
          }
          panelBody.appendChild(ideasSection);
        }

        // ── Render ────────────────────────────────────────────────────────
        buildSummary();
        buildFilters();

        const grid = document.getElementById('grid');
        for (const h of hosts) grid.appendChild(buildCard(h));

        buildGIPanel();

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
