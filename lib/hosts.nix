# Host registry — single source of truth for all deployed hosts.
# To add a new host: add an entry here, create hosts/<name>/default.nix.
# Fields:
#   system      — nixpkgs system string for this host (used for nixosSystem/deploy activation)
#   deploy      — presence generates a deploy-rs node; absence = local-only (main)
#   sshPort     — VM-only; used to filter hosts for the VM script
#   diskSize    — VM-only; used by nixos-anywhere and qemu-img
#   tailnetFQDN — per-host Tailscale FQDN; passed via hostMeta specialArg to host configs
#                 and used by the ACL generator for host-specific destinations when needed
#   tailscale   — Tailscale metadata; presence means host is on the tailnet
#     .tag        — Tailscale tag assigned to this host (without "tag:" prefix)
#     .acceptFrom — source-tag -> allowed inbound TCP ports on this host
#   homeManager — primary-user Home Manager mapping for this host
#     .role     — entrypoint module under home/users/user
#     .profiles — extra profile modules under home/profiles
#   backup      — drives modules/nixos/profiles/backup.nix retention policy
#     .class    — "critical" (14d/8w/6m/2y) | "standard" (7d/4w/3m); absent = no backup module
#   ip          — static IP (e.g. microvm guest); consumed by host network config via hostMeta
let
  knownFields = [
    "system"
    "deploy"
    "sshPort"
    "diskSize"
    "tailnetFQDN"
    "tailscale"
    "homeManager"
    "backup"
    "ip"
  ];

  knownHomeManagerRoles = [
    "desktop"
    "server"
  ];

  knownHomeManagerProfiles = [
    "desktop"
    "workstation"
  ];

  ok = cond: msg: if cond then true else throw msg;

  validateHost =
    name: cfg:
    let
      p = n: builtins.hasAttr n cfg;

      unknownFields = builtins.filter (k: !builtins.elem k knownFields) (builtins.attrNames cfg);

      checks = [
        (ok (
          unknownFields == [ ]
        ) "${name}: unknown field(s): ${builtins.concatStringsSep ", " unknownFields}")
        (ok (p "system") "${name}: missing required field 'system'")
        (ok (builtins.isString cfg.system) "${name}.system: must be a string, got ${
          builtins.typeOf (cfg.system or null)
        }")
        (ok (
          !p "deploy"
          || (builtins.isAttrs cfg.deploy && cfg.deploy ? sshUser && builtins.isString cfg.deploy.sshUser)
        ) "${name}.deploy.sshUser: must be a string")
        (ok (!p "sshPort" || builtins.isInt cfg.sshPort)
          "${name}.sshPort: must be an int, got ${builtins.typeOf (cfg.sshPort or null)}"
        )
        (ok (!p "diskSize" || builtins.isString cfg.diskSize)
          "${name}.diskSize: must be a string, got ${builtins.typeOf (cfg.diskSize or null)}"
        )
        (ok (
          !p "tailnetFQDN" || builtins.isString cfg.tailnetFQDN
        ) "${name}.tailnetFQDN: must be a string, got ${builtins.typeOf (cfg.tailnetFQDN or null)}")
        (ok (
          !p "tailscale"
          || (
            builtins.isAttrs cfg.tailscale
            && cfg.tailscale ? tag
            && builtins.isString cfg.tailscale.tag
            && (
              !cfg.tailscale ? acceptFrom
              || (
                builtins.isAttrs cfg.tailscale.acceptFrom
                && builtins.all (
                  ports:
                  builtins.isList ports && builtins.all (port: builtins.isInt port && port > 0 && port < 65536) ports
                ) (builtins.attrValues cfg.tailscale.acceptFrom)
              )
            )
          )
        ) "${name}.tailscale: expected tag string and optional acceptFrom attrset of TCP ports (1-65535)")
        (ok
          (
            !p "homeManager"
            || (
              builtins.isAttrs cfg.homeManager
              && builtins.elem (cfg.homeManager.role or null) knownHomeManagerRoles
              && (
                !cfg.homeManager ? profiles
                || (
                  builtins.isList cfg.homeManager.profiles
                  && builtins.all builtins.isString cfg.homeManager.profiles
                  && builtins.all (profile: builtins.elem profile knownHomeManagerProfiles) cfg.homeManager.profiles
                )
              )
            )
          )
          "${name}.homeManager: expected role in ${builtins.toJSON knownHomeManagerRoles} and profiles from ${builtins.toJSON knownHomeManagerProfiles}"
        )
        (ok
          (
            !p "backup"
            || (
              builtins.isAttrs cfg.backup
              && builtins.elem (cfg.backup.class or null) [
                "critical"
                "standard"
              ]
            )
          )
          "${name}.backup.class: must be \"critical\" or \"standard\", got ${
            builtins.toJSON (cfg.backup.class or null)
          }"
        )
        (ok (!p "ip" || builtins.isString cfg.ip)
          "${name}.ip: must be a string, got ${builtins.typeOf (cfg.ip or null)}"
        )
      ];

      _valid = builtins.foldl' (a: b: a && b) true checks;
    in
    builtins.seq _valid cfg;

  raw = {
    main = {
      system = "x86_64-linux";
      homeManager = {
        role = "desktop";
        profiles = [
          "desktop"
          "workstation"
        ];
      };
      tailscale.tag = "workstation";
      backup.class = "standard";
    };

    homeserver = {
      system = "x86_64-linux";
      homeManager.role = "server";
      tailnetFQDN = "homeserver.filip-nowakowicz.ts.net";
      tailscale = {
        tag = "server";
        acceptFrom.workstation = [
          22
          443
        ];
      };
      deploy.sshUser = "user";
      backup.class = "critical";
    };

    vm = {
      system = "x86_64-linux";
      homeManager = {
        role = "desktop";
        profiles = [
          "desktop"
          "workstation"
        ];
      };
      sshPort = 2222;
      diskSize = "40G";
      deploy.sshUser = "user";
    };

    homeserver-vm = {
      system = "x86_64-linux";
      homeManager.role = "server";
      ip = "10.0.100.2";
      backup.class = "critical";
    };
  };
in
builtins.mapAttrs validateHost raw
