[
  {
    id = "config-dashboard-wave-1";
    title = "Config dashboard wave 1";
    status = "now";
    priority = "p1";
    area = "platform";
    summary = "Turn the generated inventory into an operator dashboard with a structured goals board and a computed attention panel.";
    hosts = [
      "main"
      "vm"
    ];
    services = [ "inventory" ];
    blockedBy = [ ];
    unlocks = [
      "config-dashboard-wave-2"
      "config-dashboard-wave-3"
    ];
    docs = [
      "docs/goals.md"
    ];
  }
  {
    id = "gcp-homeserver";
    title = "GCP homeserver";
    status = "done";
    priority = "p1";
    area = "homeserver";
    summary = "Boot the homeserver configuration on GCE — Tailscale, Vaultwarden, Syncthing, LGTM stack, and Restic backups to B2.";
    hosts = [ "homeserver-gcp" ];
    services = [
      "tailscale"
      "vaultwarden"
      "syncthing"
    ];
    blockedBy = [ ];
    unlocks = [
      "deploy-pipeline"
      "b2-backups"
      "adguard"
      "lgtm-tuning"
    ];
    docs = [
      "docs/goals.md"
      "hosts/homeserver-gcp/CLAUDE.md"
    ];
  }
  {
    id = "deploy-pipeline";
    title = "Automated deploy pipeline";
    status = "next";
    priority = "p2";
    area = "deploy";
    summary = "Add a self-hosted Actions runner, extend smoke coverage, and automate homeserver-gcp then main deployment after passing checks.";
    hosts = [
      "homeserver-gcp"
      "main"
    ];
    services = [
      "deploy-rs"
      "github-actions"
      "smoke-tests"
    ];
    blockedBy = [
      "gcp-homeserver"
    ];
    unlocks = [ "secret-rotation" ];
    docs = [ "docs/goals.md" ];
  }
  {
    id = "b2-backups";
    title = "Off-site backup (B2)";
    status = "next";
    priority = "p2";
    area = "backup";
    summary = "Replace the local-only main restic target with Backblaze B2 — homeserver-gcp already uses B2.";
    hosts = [
      "homeserver-gcp"
      "main"
    ];
    services = [
      "restic"
      "b2"
    ];
    blockedBy = [
      "gcp-homeserver"
    ];
    unlocks = [ ];
    docs = [ "docs/goals.md" ];
  }
  {
    id = "adguard";
    title = "Local DNS and ad-blocking";
    status = "next";
    priority = "p2";
    area = "homeserver";
    summary = "Deploy AdGuard Home behind the homeserver and connect it to Tailscale MagicDNS for network-wide filtering.";
    hosts = [ "homeserver-gcp" ];
    services = [
      "adguard"
      "tailscale"
    ];
    blockedBy = [
      "gcp-homeserver"
    ];
    unlocks = [ ];
    docs = [ "docs/goals.md" ];
  }
  {
    id = "lgtm-tuning";
    title = "LGTM tuning";
    status = "next";
    priority = "p2";
    area = "observability";
    summary = "Expand dashboards and alerts, then tune retention and cardinality for longer-running operation.";
    hosts = [
      "main"
      "homeserver-gcp"
    ];
    services = [
      "lgtm"
      "grafana"
      "loki"
      "prometheus"
    ];
    blockedBy = [
      "gcp-homeserver"
    ];
    unlocks = [ "host-introspection" ];
    docs = [ "docs/goals.md" ];
  }
  {
    id = "config-dashboard-wave-2";
    title = "Config dashboard wave 2";
    status = "later";
    priority = "p2";
    area = "platform";
    summary = "Add validation commands, dependency context, and richer host/service relationships to the dashboard.";
    hosts = [
      "main"
      "homeserver-gcp"
      "vm"
    ];
    services = [
      "inventory"
      "deploy-rs"
      "smoke-tests"
    ];
    blockedBy = [ "config-dashboard-wave-1" ];
    unlocks = [ ];
    docs = [
      "docs/goals.md"
    ];
  }
  {
    id = "config-dashboard-wave-3";
    title = "Config dashboard wave 3";
    status = "done";
    priority = "p3";
    area = "platform";
    summary = "Add closure-size, invariant, and validation-health signals so the dashboard can show drift and cost as well as structure.";
    hosts = [
      "main"
      "homeserver-gcp"
      "vm"
    ];
    services = [
      "inventory"
      "checks"
    ];
    blockedBy = [ "config-dashboard-wave-1" ];
    unlocks = [ ];
    docs = [
      "docs/goals.md"
    ];
  }
  {
    id = "host-introspection";
    title = "Host introspection to LGTM";
    status = "later";
    priority = "p3";
    area = "observability";
    summary = "Feed auditd, osquery, or lynis output into Loki so the observability stack proves its value beyond infra metrics.";
    hosts = [
      "main"
      "homeserver-gcp"
    ];
    services = [
      "lgtm"
      "auditd"
      "osquery"
    ];
    blockedBy = [ "lgtm-tuning" ];
    unlocks = [ ];
    docs = [ "docs/goals.md" ];
  }
  {
    id = "service-composition-dsl";
    title = "Service composition DSL";
    status = "later";
    priority = "p3";
    area = "platform";
    summary = "Create a declarative app module that auto-wires hardening, observability, backup, and port plumbing for new services.";
    hosts = [
      "homeserver-gcp"
    ];
    services = [
      "sandboxing"
      "restic"
      "lgtm"
    ];
    blockedBy = [ ];
    unlocks = [ ];
    docs = [ "docs/goals.md" ];
  }
  {
    id = "typed-generators";
    title = "Expand typed generators";
    status = "later";
    priority = "p3";
    area = "platform";
    summary = "Extend the typed generator approach beyond Alloy and Grafana into other declarative domains such as nginx vhosts and timers.";
    hosts = [
      "main"
      "homeserver-gcp"
    ];
    services = [
      "alloy"
      "grafana"
      "nginx"
    ];
    blockedBy = [ ];
    unlocks = [ ];
    docs = [ "docs/goals.md" ];
  }
  {
    id = "secret-rotation";
    title = "Secret rotation ritual";
    status = "later";
    priority = "p3";
    area = "security";
    summary = "Define a repeatable secret rotation checklist and expose age or rotation health through observability signals.";
    hosts = [
      "main"
      "homeserver-gcp"
    ];
    services = [
      "sops"
      "age"
    ];
    blockedBy = [ "deploy-pipeline" ];
    unlocks = [ ];
    docs = [ "docs/goals.md" ];
  }
]
