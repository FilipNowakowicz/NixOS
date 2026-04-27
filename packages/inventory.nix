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

        /* ── Roadmap & Ideas ── */
        .section-panel-title {
          font-size: 0.7rem;
          text-transform: uppercase;
          letter-spacing: 0.1em;
          color: var(--muted);
          font-weight: 600;
        }
        .panel-hdr {
          display: flex;
          align-items: center;
          justify-content: space-between;
          margin-bottom: 0.75rem;
        }
        .panel-meta {
          font-size: 0.72rem;
          color: var(--muted);
          display: flex;
          align-items: center;
          gap: 0.5rem;
        }
        .prog-bar {
          display: inline-block;
          width: 64px;
          height: 3px;
          background: var(--border);
          border-radius: 2px;
          overflow: hidden;
        }
        .prog-bar-fill { height: 100%; background: var(--green); }
        .roadmap-tracks {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 0.75rem;
        }
        .roadmap-track {
          background: var(--surface);
          border: 1px solid var(--border);
          border-radius: 6px;
          overflow: hidden;
        }
        .roadmap-track-header {
          display: flex;
          align-items: center;
          gap: 0.4rem;
          padding: 0.45rem 0.75rem;
          border-bottom: 1px solid var(--border);
        }
        .roadmap-track-label {
          font-size: 0.68rem;
          text-transform: uppercase;
          letter-spacing: 0.07em;
          font-weight: 600;
          flex: 1;
        }
        .track-a .roadmap-track-label { color: var(--green); }
        .track-b .roadmap-track-label { color: var(--yellow); }
        .roadmap-track-badge {
          font-size: 0.62rem;
          padding: 1px 5px;
          border-radius: 3px;
          border: 1px solid;
        }
        .badge-cloud { color: var(--blue); border-color: var(--blue); }
        .badge-blocked { color: var(--red); border-color: var(--red); }
        .roadmap-connector-label {
          text-align: center;
          font-size: 0.68rem;
          color: var(--muted);
          padding: 0.4rem 0;
          letter-spacing: 0.04em;
        }
        .roadmap-deferred {
          background: var(--surface);
          border: 1px solid var(--border);
          border-radius: 6px;
          overflow: hidden;
          margin-bottom: 1.25rem;
        }
        .roadmap-group-header {
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 0.45rem 0.75rem;
          border-bottom: 1px solid var(--border);
        }
        .roadmap-group-label {
          font-size: 0.68rem;
          text-transform: uppercase;
          letter-spacing: 0.07em;
          font-weight: 600;
          color: var(--blue);
        }
        .roadmap-group-count { font-size: 0.68rem; color: var(--muted); }
        .goal-items-list { padding: 0.3rem 0; }
        .goal-item {
          display: flex;
          align-items: flex-start;
          gap: 0.5rem;
          padding: 0.28rem 0.75rem;
          cursor: pointer;
          transition: background 0.1s;
        }
        .goal-item:hover { background: #1c2128; }
        .goal-item.expanded { background: #161f2e; }
        .goal-dot {
          width: 7px;
          height: 7px;
          border-radius: 50%;
          border: 1.5px solid var(--muted);
          flex-shrink: 0;
          margin-top: 5px;
        }
        .goal-dot.done { background: var(--green); border-color: var(--green); }
        .goal-title { font-size: 0.78rem; color: var(--text); line-height: 1.4; }
        .goal-title.done { color: var(--muted); text-decoration: line-through; }
        .goal-desc {
          font-size: 0.72rem;
          color: var(--muted);
          line-height: 1.55;
          margin-top: 0.25rem;
        }
        .goal-desc.hidden { display: none; }
        .ideas-grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
          gap: 0.75rem;
        }
        .idea-card {
          background: var(--surface);
          border: 1px solid var(--border);
          border-radius: 6px;
          padding: 0.75rem;
          cursor: pointer;
          transition: border-color 0.15s;
        }
        .idea-card:hover { border-color: var(--muted); }
        .idea-card.expanded { border-color: var(--purple); }
        .idea-num {
          font-size: 0.62rem;
          color: var(--muted);
          font-weight: 600;
          letter-spacing: 0.06em;
          margin-bottom: 0.3rem;
          opacity: 0.6;
        }
        .idea-title { font-size: 0.8rem; color: var(--text); line-height: 1.35; }
        .idea-desc {
          display: none;
          font-size: 0.72rem;
          color: var(--muted);
          line-height: 1.55;
          margin-top: 0.4rem;
          padding-top: 0.4rem;
          border-top: 1px solid var(--border);
        }
        .idea-card.expanded .idea-desc { display: block; }

        footer { margin-top: 2rem; color: var(--muted); font-size: 0.8rem; }
      </style>
    </head>
    <body>
      <h1>NixOS Fleet Inventory</h1>
      <p class="subtitle">Generated from flake evaluation &bull; nix build '.#inventory'</p>

      <div class="summary" id="summary"></div>
      <div class="filters" id="filters"></div>
      <div class="grid" id="grid"></div>
      <div id="gi-section"></div>
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

        // ── Roadmap ───────────────────────────────────────────────────────

        function buildGoalItem(it) {
          const item = el('div', 'goal-item');
          const dot = el('span', 'goal-dot' + (it.done ? ' done' : ""));
          const textWrap = document.createElement('div');
          textWrap.appendChild(el('div', 'goal-title' + (it.done ? ' done' : ""), it.title));
          if (it.desc) {
            const desc = el('div', 'goal-desc hidden', it.desc);
            textWrap.appendChild(desc);
            item.addEventListener('click', function() {
              item.classList.toggle('expanded');
              desc.classList.toggle('hidden');
            });
          }
          item.appendChild(dot);
          item.appendChild(textWrap);
          return item;
        }

        function buildTrack(type, group) {
          const track = el('div', 'roadmap-track track-' + type);
          const header = el('div', 'roadmap-track-header');
          header.appendChild(el('span', 'roadmap-track-label', group.label));
          header.appendChild(el('span', 'roadmap-track-badge ' + (type === 'a' ? 'badge-cloud' : 'badge-blocked'), type === 'a' ? 'cloud' : 'blocked'));
          track.appendChild(header);
          const items = el('div', 'goal-items-list');
          for (const it of group.items) items.appendChild(buildGoalItem(it));
          track.appendChild(items);
          return track;
        }

        function buildRoadmap() {
          const wrap = document.createElement('div');
          wrap.style.marginTop = '2rem';

          const goalSections = parseGoals(goalsText);
          let total = 0, done = 0;
          for (const sec of goalSections)
            for (const g of sec.groups)
              for (const it of g.items) { total++; if (it.done) done++; }

          const hdr = el('div', 'panel-hdr');
          hdr.appendChild(el('span', 'section-panel-title', 'Roadmap'));
          const metaWrap = el('span', 'panel-meta');
          metaWrap.appendChild(document.createTextNode(done + ' / ' + total + ' complete\u00a0'));
          const pb = el('span', 'prog-bar');
          const pbf = el('span', 'prog-bar-fill');
          pbf.style.width = (total ? Math.round(done / total * 100) : 0) + '%';
          pb.appendChild(pbf);
          metaWrap.appendChild(pb);
          hdr.appendChild(metaWrap);
          wrap.appendChild(hdr);

          let pathA = null, pathB = null, deferred = null;
          const others = [];
          for (const sec of goalSections) {
            for (const g of sec.groups) {
              if (!g.label) continue;
              if (/path\s+a/i.test(g.label)) pathA = g;
              else if (/path\s+b/i.test(g.label)) pathB = g;
              else if (/deferred/i.test(g.label)) deferred = g;
              else others.push(g);
            }
          }

          if (pathA || pathB) {
            const tracks = el('div', 'roadmap-tracks');
            if (pathA) tracks.appendChild(buildTrack('a', pathA));
            if (pathB) tracks.appendChild(buildTrack('b', pathB));
            wrap.appendChild(tracks);
          }

          if (deferred) {
            wrap.appendChild(el('div', 'roadmap-connector-label', '\u2193 either path unlocks \u2193'));
            const dcard = el('div', 'roadmap-deferred');
            const dh = el('div', 'roadmap-group-header');
            dh.appendChild(el('span', 'roadmap-group-label', 'Deferred'));
            const remaining = deferred.items.filter(function(i) { return !i.done; }).length;
            dh.appendChild(el('span', 'roadmap-group-count', remaining + ' pending'));
            dcard.appendChild(dh);
            const dItems = el('div', 'goal-items-list');
            for (const it of deferred.items) dItems.appendChild(buildGoalItem(it));
            dcard.appendChild(dItems);
            wrap.appendChild(dcard);
          }

          for (const g of others) {
            const gcard = el('div', 'roadmap-deferred');
            const gh = el('div', 'roadmap-group-header');
            gh.appendChild(el('span', 'roadmap-group-label', g.label || ""));
            gcard.appendChild(gh);
            const gItems = el('div', 'goal-items-list');
            for (const it of g.items) gItems.appendChild(buildGoalItem(it));
            gcard.appendChild(gItems);
            wrap.appendChild(gcard);
          }

          return wrap;
        }

        // ── Ideas Backlog ─────────────────────────────────────────────────

        function buildIdeas() {
          const wrap = document.createElement('div');
          wrap.style.marginTop = '1.5rem';

          const ideas = parseIdeas(ideasText);

          const hdr = el('div', 'panel-hdr');
          hdr.appendChild(el('span', 'section-panel-title', 'Ideas Backlog'));
          hdr.appendChild(el('span', 'panel-meta', ideas.length + ' ideas'));
          wrap.appendChild(hdr);

          const grid = el('div', 'ideas-grid');
          for (const it of ideas) {
            const card = el('div', 'idea-card');
            card.appendChild(el('div', 'idea-num', String(it.num).padStart(2, '0')));
            card.appendChild(el('div', 'idea-title', it.title));
            if (it.desc) card.appendChild(el('div', 'idea-desc', it.desc));
            card.addEventListener('click', function() { card.classList.toggle('expanded'); });
            grid.appendChild(card);
          }
          wrap.appendChild(grid);

          return wrap;
        }

        // ── Render ────────────────────────────────────────────────────────
        buildSummary();
        buildFilters();

        const grid = document.getElementById('grid');
        for (const h of hosts) grid.appendChild(buildCard(h));

        const gi = document.getElementById('gi-section');
        gi.appendChild(buildRoadmap());
        gi.appendChild(buildIdeas());

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
