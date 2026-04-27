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
        .subtitle { color: var(--muted); font-size: 0.85rem; margin-bottom: 2rem; }
        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(360px, 1fr)); gap: 1rem; }
        .card {
          background: var(--surface);
          border: 1px solid var(--border);
          border-radius: 6px;
          padding: 1rem 1.25rem;
        }
        .card-header {
          display: flex;
          align-items: baseline;
          gap: 0.5rem;
          margin-bottom: 0.75rem;
          border-bottom: 1px solid var(--border);
          padding-bottom: 0.5rem;
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
        .tag-hm { color: var(--purple); border-color: #7a5af855; }
        footer { margin-top: 2rem; color: var(--muted); font-size: 0.8rem; }
      </style>
    </head>
    <body>
      <h1>NixOS Fleet Inventory</h1>
      <p class="subtitle">Generated from flake evaluation &bull; nix build '.#inventory'</p>
      <div class="grid" id="grid"></div>
      <footer id="footer"></footer>

      <script>
        const hosts = ${dataJson};

        const svcLabels = {
          openssh: 'SSH', tailscale: 'Tailscale', firewall: 'Firewall',
          fail2ban: 'fail2ban', vaultwarden: 'Vaultwarden', syncthing: 'Syncthing',
          hyprland: 'Hyprland', observabilityStack: 'LGTM', observabilityClient: 'OTel',
          usbguard: 'USBGuard', lanzaboote: 'Lanzaboote',
        };

        function el(tag, cls, text) {
          const e = document.createElement(tag);
          if (cls) e.className = cls;
          if (text !== undefined) e.textContent = text;
          return e;
        }

        function buildCard(h) {
          const card = el('div', 'card');

          // Header
          const header = el('div', 'card-header');
          header.appendChild(el('span', 'hostname', h.name));
          if (h.deployable) header.appendChild(el('span', 'badge badge-deploy', 'deploy-rs'));
          if (h.backupClass === 'critical') header.appendChild(el('span', 'badge badge-backup-critical', 'backup:critical'));
          if (h.backupClass === 'standard') header.appendChild(el('span', 'badge badge-backup-standard', 'backup:standard'));
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

          // Services
          card.appendChild(el('div', 'section-title', 'Services'));
          const svcs = el('div', 'tags');
          for (const [key, enabled] of Object.entries(h.services)) {
            svcs.appendChild(el('span', 'tag ' + (enabled ? 'tag-on' : 'tag-off'), svcLabels[key] ?? key));
          }
          card.appendChild(svcs);

          return card;
        }

        const grid = document.getElementById('grid');
        for (const h of hosts) grid.appendChild(buildCard(h));

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
