[
  {
    id = "deploy-pipeline";
    title = "Automated deploy pipeline";
    status = "later";
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
    blockedBy = [ ];
    unlocks = [ "secret-rotation" ];
    docs = [
      "docs/goals.md"
      "docs/homeserver-goals.md"
    ];
  }
  {
    id = "tailscale-aware-grafana-sso";
    title = "Tailscale-aware Grafana SSO";
    status = "later";
    priority = "p2";
    area = "security";
    summary = "Replace Grafana local admin login with tailnet identity after the proxy and break-glass story are clear.";
    hosts = [ "homeserver-gcp" ];
    services = [
      "tailscale"
      "grafana"
      "nginx"
    ];
    blockedBy = [ ];
    unlocks = [ ];
    docs = [ "docs/homeserver-goals.md" ];
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
    blockedBy = [ ];
    unlocks = [ ];
    docs = [
      "docs/goals.md"
    ];
  }
  {
    id = "service-composition-dsl";
    title = "Service composition DSL";
    status = "deferred";
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
    docs = [ "docs/homeserver-goals.md" ];
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
    docs = [ "docs/homeserver-goals.md" ];
  }
  {
    id = "secret-rotation";
    title = "Secret rotation ritual";
    status = "deferred";
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
    docs = [
      "docs/goals.md"
      "docs/homeserver-goals.md"
    ];
  }
]
