# Typed Alloy & Grafana Generators Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the string heredoc Alloy config and `builtins.toJSON` dashboard in `observability.nix` with typed Nix attrset builders — `lib/generators.nix` (toAlloyHCL) and `lib/dashboards.nix` — producing type-safe, diffable, testable observability configuration.

**Architecture:** `lib/generators.nix` provides a `toAlloyHCL` function that serializes a list of component definitions (attrsets with `type`, `label`, `body`) into Alloy River syntax, with `ref` and `nestedBlock` constructors for unquoted expressions and nested structural blocks. `lib/dashboards.nix` provides typed builder functions (`mkDashboard`, `timeseriesPanel`, `logsPanel`, `target`, `gridPos`, standard datasource refs) so dashboards are composed rather than hand-written. `observability.nix` imports both and replaces all heredoc/toJSON construction with calls to these builders.

**Tech Stack:** Nix, `lib.runTests` for unit testing, `nix flake check` for integration validation, `statix` / `deadnix` for linting.

---

## File Structure

| Action | Path                                       | Responsibility                                                                                     |
| ------ | ------------------------------------------ | -------------------------------------------------------------------------------------------------- |
| Create | `lib/generators.nix`                       | `toAlloyHCL`, `ref`, `nestedBlock` — Alloy River serializer                                        |
| Create | `lib/dashboards.nix`                       | `mkDashboard`, `timeseriesPanel`, `logsPanel`, `target`, `gridPos`, `mimirDS`, `lokiDS`, `tempoDS` |
| Create | `tests/lib/generators.nix`                 | `lib.runTests` unit tests for generators                                                           |
| Modify | `flake.nix`                                | Add `lib-generators` check to `checks.${system}`                                                   |
| Modify | `modules/nixos/profiles/observability.nix` | Remove heredoc/toJSON, use generators                                                              |

---

## Task 1: Create `lib/generators.nix`

**Files:**

- Create: `lib/generators.nix`

- [ ] **Step 1: Write `lib/generators.nix`**

```nix
# Generators for serializing Nix attrsets to domain-specific config formats.
{ lib }:

let
  indentStr = depth: lib.concatStrings (lib.replicate depth "  ");

  isRef = v: lib.isAttrs v && v ? __alloyRef;
  isBlock = v: lib.isAttrs v && v ? __alloyBlock;

  renderValue =
    depth: v:
    if isRef v then
      v.__alloyRef
    else if lib.isString v then
      "\"${lib.escape [ "\"" "\\" ] v}\""
    else if lib.isInt v || lib.isFloat v then
      toString v
    else if lib.isBool v then
      (if v then "true" else "false")
    else if lib.isList v then
      "[${lib.concatStringsSep ", " (map (renderValue depth) v)}]"
    else if lib.isAttrs v && !isBlock v then
      let
        pairs = lib.mapAttrsToList (
          k: val: "${indentStr (depth + 1)}${k} = ${renderValue (depth + 1) val},"
        ) v;
      in
      "{\n${lib.concatStringsSep "\n" pairs}\n${indentStr depth}}"
    else
      throw "toAlloyHCL: unsupported value type: ${lib.generators.toPretty { } v}";

  renderBody =
    depth: attrs:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: value:
        if isBlock value then
          let body = lib.removeAttrs value [ "__alloyBlock" ];
          in "${indentStr depth}${name} {\n${renderBody (depth + 1) body}\n${indentStr depth}}"
        else
          "${indentStr depth}${name} = ${renderValue depth value}"
      ) attrs
    );

  renderComponent =
    { type, label, body }:
    "${type} \"${label}\" {\n${renderBody 1 body}\n}";

in
{
  # Convert a list of Alloy component definitions to River config text.
  # Each component: { type = "loki.write"; label = "target"; body = { ... }; }
  # body values: strings, ints, bools, lists, inline attrsets,
  #   ref "expr" for unquoted expressions, nestedBlock { } for sub-blocks.
  toAlloyHCL = components: lib.concatStringsSep "\n\n" (map renderComponent components);

  # Unquoted Alloy expression — use for component references in forward_to etc.
  ref = expr: { __alloyRef = expr; };

  # Nested block (rendered as `name { ... }` not `name = { ... }`)
  nestedBlock = body: { __alloyBlock = true; } // body;
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/generators.nix
git commit -m "feat: add lib/generators.nix with toAlloyHCL serializer"
```

---

## Task 2: Verify `toAlloyHCL` output with `nix eval`

**Files:**

- Read: `lib/generators.nix`

- [ ] **Step 1: Test simple component**

```bash
nix eval --raw --impure --expr '
  let lib = (builtins.getFlake "nixpkgs").lib;
      gen = import ./lib/generators.nix { inherit lib; };
  in gen.toAlloyHCL [
    { type = "loki.write"; label = "target"; body = { url = "http://loki"; }; }
  ]
'
```

Expected output:

```
loki.write "target" {
  url = "http://loki"
}
```

- [ ] **Step 2: Test nested block + ref**

```bash
nix eval --raw --impure --expr '
  let lib = (builtins.getFlake "nixpkgs").lib;
      gen = import ./lib/generators.nix { inherit lib; };
  in gen.toAlloyHCL [
    {
      type = "loki.write";
      label = "target";
      body = {
        endpoint = gen.nestedBlock { url = "http://loki"; };
      };
    }
    {
      type = "loki.source.journal";
      label = "systemd";
      body = {
        forward_to = [ (gen.ref "loki.write.target.receiver") ];
        max_age = "12h";
      };
    }
  ]
'
```

Expected output (alphabetical key order):

```
loki.write "target" {
  endpoint {
    url = "http://loki"
  }
}

loki.source.journal "systemd" {
  forward_to = [loki.write.target.receiver]
  max_age = "12h"
}
```

- [ ] **Step 3: Test inline object (labels map)**

```bash
nix eval --raw --impure --expr '
  let lib = (builtins.getFlake "nixpkgs").lib;
      gen = import ./lib/generators.nix { inherit lib; };
  in gen.toAlloyHCL [
    {
      type = "loki.source.journal";
      label = "systemd";
      body = {
        labels = { host = "myhost"; job = "systemd-journal"; };
        max_age = "12h";
      };
    }
  ]
'
```

Expected output:

```
loki.source.journal "systemd" {
  labels = {
    host = "myhost",
    job = "systemd-journal",
  }
  max_age = "12h"
}
```

---

## Task 3: Create `lib/dashboards.nix`

**Files:**

- Create: `lib/dashboards.nix`

- [ ] **Step 1: Write `lib/dashboards.nix`**

```nix
# Builder helpers for Grafana dashboards as typed Nix attrsets.
{ lib }:

{
  # Grid position builder
  gridPos =
    {
      x ? 0,
      y ? 0,
      w ? 12,
      h ? 8,
    }:
    { inherit x y w h; };

  # Standard datasource references
  mimirDS = { uid = "mimir"; type = "prometheus"; };
  lokiDS  = { uid = "loki";  type = "loki"; };
  tempoDS = { uid = "tempo"; type = "tempo"; };

  # Generic datasource reference
  datasource = uid: type: { inherit uid type; };

  # Query target builder
  target =
    {
      expr,
      legendFormat ? "",
      refId ? "A",
    }:
    { inherit expr legendFormat refId; };

  # Timeseries panel builder
  timeseriesPanel =
    {
      id,
      title,
      ds,
      targets,
      gridPos,
    }:
    {
      inherit id title targets gridPos;
      type = "timeseries";
      datasource = ds;
    };

  # Logs panel builder
  logsPanel =
    {
      id,
      title,
      ds,
      targets,
      gridPos,
    }:
    {
      inherit id title targets gridPos;
      type = "logs";
      datasource = ds;
    };

  # Dashboard builder with sensible defaults
  mkDashboard =
    {
      uid,
      title,
      panels,
      refresh ? "30s",
      timeFrom ? "now-1h",
      timeTo ? "now",
    }:
    {
      id = null;
      inherit uid title panels refresh;
      timezone = "browser";
      schemaVersion = 39;
      version = 1;
      time = {
        from = timeFrom;
        to = timeTo;
      };
    };
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/dashboards.nix
git commit -m "feat: add lib/dashboards.nix with typed Grafana dashboard builders"
```

---

## Task 4: Verify `dashboards.nix` output with `nix eval`

**Files:**

- Read: `lib/dashboards.nix`

- [ ] **Step 1: Test dashboard JSON roundtrip**

```bash
nix eval --json --impure --expr '
  let lib = (builtins.getFlake "nixpkgs").lib;
      dash = import ./lib/dashboards.nix { inherit lib; };
  in dash.mkDashboard {
    uid = "test";
    title = "Test Dashboard";
    panels = [
      (dash.timeseriesPanel {
        id = 1;
        title = "CPU";
        ds = dash.mimirDS;
        gridPos = dash.gridPos { x = 0; y = 0; w = 12; h = 8; };
        targets = [ (dash.target { expr = "up"; legendFormat = "{{instance}}"; }) ];
      })
    ];
  }
' | python3 -m json.tool
```

Expected: valid JSON with `uid`, `title`, `panels`, `timezone`, `schemaVersion`, `version`, `refresh`, `time` fields. Panel should have `type = "timeseries"`, `datasource.uid = "mimir"`.

---

## Task 5: Add unit tests for generators

**Files:**

- Create: `tests/lib/generators.nix`
- Modify: `flake.nix` (add check)

- [ ] **Step 1: Write `tests/lib/generators.nix`**

```nix
{
  nixpkgs,
  system,
  ...
}:
let
  lib = nixpkgs.lib;
  pkgs = nixpkgs.legacyPackages.${system};
  gen = import ../../lib/generators.nix { inherit lib; };

  failures = lib.runTests {
    testStringAttribute = {
      expr = gen.toAlloyHCL [
        {
          type = "loki.write";
          label = "target";
          body = {
            url = "http://loki:3100";
          };
        }
      ];
      expected = "loki.write \"target\" {\n  url = \"http://loki:3100\"\n}";
    };

    testBoolAttribute = {
      expr = gen.toAlloyHCL [
        {
          type = "x";
          label = "y";
          body = {
            enabled = true;
            debug = false;
          };
        }
      ];
      expected = "x \"y\" {\n  debug = false\n  enabled = true\n}";
    };

    testNestedBlock = {
      expr = gen.toAlloyHCL [
        {
          type = "loki.write";
          label = "target";
          body = {
            endpoint = gen.nestedBlock {
              url = "http://loki:3100";
            };
          };
        }
      ];
      expected = "loki.write \"target\" {\n  endpoint {\n    url = \"http://loki:3100\"\n  }\n}";
    };

    testRefInList = {
      expr = gen.toAlloyHCL [
        {
          type = "loki.source.journal";
          label = "systemd";
          body = {
            forward_to = [ (gen.ref "loki.write.target.receiver") ];
          };
        }
      ];
      expected = "loki.source.journal \"systemd\" {\n  forward_to = [loki.write.target.receiver]\n}";
    };

    testInlineObject = {
      expr = gen.toAlloyHCL [
        {
          type = "loki.source.journal";
          label = "systemd";
          body = {
            labels = {
              job = "systemd-journal";
            };
          };
        }
      ];
      expected = "loki.source.journal \"systemd\" {\n  labels = {\n    job = \"job\",\n  }\n}";
    };

    testMultipleComponents = {
      expr = gen.toAlloyHCL [
        { type = "a"; label = "1"; body = { x = "1"; }; }
        { type = "b"; label = "2"; body = { y = "2"; }; }
      ];
      expected = "a \"1\" {\n  x = \"1\"\n}\n\nb \"2\" {\n  y = \"2\"\n}";
    };

    testDeepNestedBlock = {
      expr = gen.toAlloyHCL [
        {
          type = "loki.write";
          label = "target";
          body = {
            endpoint = gen.nestedBlock {
              basic_auth = gen.nestedBlock {
                username = "user";
                password_file = "/run/secrets/pw";
              };
              url = "http://loki";
            };
          };
        }
      ];
      expected = "loki.write \"target\" {\n  endpoint {\n    basic_auth {\n      password_file = \"/run/secrets/pw\"\n      username = \"user\"\n    }\n    url = \"http://loki\"\n  }\n}";
    };
  };
in
if failures == [ ] then
  pkgs.runCommand "lib-generators-tests" { } "touch $out"
else
  throw "lib/generators.nix tests failed:\n${lib.generators.toPretty { } failures}"
```

- [ ] **Step 2: Wire into `flake.nix` checks**

In `flake.nix`, find this block (around line 202):

```nix
checks.${system} = deploy-rs.lib.${system}.deployChecks self.deploy // {
  homeserver-vm-smoke = import ./tests/nixos/homeserver-vm-smoke.nix {
    inherit nixpkgs system inputs;
  };
};
```

Replace with:

```nix
checks.${system} = deploy-rs.lib.${system}.deployChecks self.deploy // {
  homeserver-vm-smoke = import ./tests/nixos/homeserver-vm-smoke.nix {
    inherit nixpkgs system inputs;
  };
  lib-generators = import ./tests/lib/generators.nix {
    inherit nixpkgs system;
  };
};
```

- [ ] **Step 3: Fix the inline object test**

The `testInlineObject` expected value above has a bug — the value `"job"` should be `"systemd-journal"`. Open `tests/lib/generators.nix` and fix line:

Change:

```nix
expected = "loki.source.journal \"systemd\" {\n  labels = {\n    job = \"job\",\n  }\n}";
```

To:

```nix
expected = "loki.source.journal \"systemd\" {\n  labels = {\n    job = \"systemd-journal\",\n  }\n}";
```

- [ ] **Step 4: Run the tests**

```bash
nix build .#checks.x86_64-linux.lib-generators --no-link
```

Expected: build succeeds (derivation touches `$out`). If tests fail the build will error with the failure list.

- [ ] **Step 5: Commit**

```bash
git add tests/lib/generators.nix flake.nix
git commit -m "test: add lib.runTests unit tests for lib/generators.nix"
```

---

## Task 6: Refactor `modules/nixos/profiles/observability.nix`

**Files:**

- Modify: `modules/nixos/profiles/observability.nix`

- [ ] **Step 1: Replace the `let` block at the top of the file**

Replace lines 1–122 (the entire file header through `dashboardJson`) with the following. The `config =` block and everything after line 124 stays unchanged.

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.profiles.observability;
  gen = import ../../../lib/generators.nix { inherit lib; };
  dash = import ../../../lib/dashboards.nix { inherit lib; };

  shouldUseIngestAuth = cfg.ingestAuth.username != null && cfg.ingestAuth.passwordFile != null;
  metricsRemoteWriteAuth = lib.optionalAttrs shouldUseIngestAuth {
    basic_auth = {
      username = cfg.ingestAuth.username;
      password_file = toString cfg.ingestAuth.passwordFile;
    };
  };

  alloyConfig = gen.toAlloyHCL [
    {
      type = "loki.write";
      label = "target";
      body = {
        endpoint = gen.nestedBlock (
          { url = cfg.collectors.logs.pushURL; }
          // lib.optionalAttrs shouldUseIngestAuth {
            basic_auth = gen.nestedBlock {
              password_file = toString cfg.ingestAuth.passwordFile;
              username = cfg.ingestAuth.username;
            };
          }
        );
      };
    }
    {
      type = "loki.source.journal";
      label = "systemd";
      body = {
        forward_to = [ (gen.ref "loki.write.target.receiver") ];
        labels = {
          host = config.networking.hostName;
          job = "systemd-journal";
        };
        max_age = "12h";
      };
    }
  ];

  fleetDashboard = dash.mkDashboard {
    uid = "homeserver-fleet-overview";
    title = "Homeserver Fleet Overview";
    panels = [
      (dash.timeseriesPanel {
        id = 1;
        title = "CPU Usage %";
        ds = dash.mimirDS;
        gridPos = dash.gridPos {
          x = 0;
          y = 0;
          w = 12;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
            legendFormat = "{{instance}}";
          })
        ];
      })
      (dash.logsPanel {
        id = 2;
        title = "Systemd Journal Logs";
        ds = dash.lokiDS;
        gridPos = dash.gridPos {
          x = 0;
          y = 8;
          w = 24;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "{job=\"systemd-journal\"}";
          })
        ];
      })
      (dash.timeseriesPanel {
        id = 3;
        title = "Memory Usage %";
        ds = dash.mimirDS;
        gridPos = dash.gridPos {
          x = 12;
          y = 0;
          w = 12;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
            legendFormat = "{{instance}}";
          })
        ];
      })
    ];
  };

in
```

- [ ] **Step 2: Update `environment.etc` to use new bindings**

Find this block in `observability.nix` (around line 402 in the original):

```nix
environment.etc = lib.mkMerge [
  (lib.mkIf cfg.grafana.enable {
    "grafana-dashboards/homeserver-fleet-overview.json".text = dashboardJson;
  })
  (lib.mkIf cfg.collectors.logs.enable {
    "alloy/config.alloy".text = alloyConfig;
  })
];
```

The `alloyConfig` binding name is unchanged. Replace only `dashboardJson` with `builtins.toJSON fleetDashboard`:

```nix
environment.etc = lib.mkMerge [
  (lib.mkIf cfg.grafana.enable {
    "grafana-dashboards/homeserver-fleet-overview.json".text = builtins.toJSON fleetDashboard;
  })
  (lib.mkIf cfg.collectors.logs.enable {
    "alloy/config.alloy".text = alloyConfig;
  })
];
```

- [ ] **Step 3: Verify the file has no remaining references to the old bindings**

```bash
grep -n 'alloyBasicAuth\|dashboardJson\|heredoc' modules/nixos/profiles/observability.nix
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/profiles/observability.nix
git commit -m "refactor: use typed Nix generators for Alloy config and Grafana dashboard"
```

---

## Task 7: Validate the full config

**Files:**

- Read result of validation

- [ ] **Step 1: Lint**

```bash
statix check . && deadnix .
```

Expected: no output / no issues for the three new/changed files.

- [ ] **Step 2: Build homeserver config (the only host using observability)**

```bash
nix build .#nixosConfigurations.homeserver.config.system.build.toplevel --no-link
```

Expected: succeeds with no errors.

- [ ] **Step 3: Run all checks**

```bash
nix build .#checks.x86_64-linux.lib-generators --no-link
```

Expected: succeeds.

- [ ] **Step 4: Verify generated Alloy config looks correct**

```bash
nix eval --raw .#nixosConfigurations.homeserver.config.environment.etc."alloy/config.alloy".text
```

Expected — something like (exact values depend on host config):

```
loki.write "target" {
  endpoint {
    url = "http://127.0.0.1:3100/loki/api/v1/push"
  }
}

loki.source.journal "systemd" {
  forward_to = [loki.write.target.receiver]
  labels = {
    host = "homeserver",
    job = "systemd-journal",
  }
  max_age = "12h"
}
```

- [ ] **Step 5: Verify generated Grafana dashboard JSON is valid**

```bash
nix eval --json .#nixosConfigurations.homeserver.config.environment.etc."grafana-dashboards/homeserver-fleet-overview.json".text \
  | python3 -c 'import json,sys; d=json.loads(json.load(sys.stdin)); print(d["uid"], len(d["panels"]), "panels")'
```

Expected output: `homeserver-fleet-overview 3 panels`

---

## Self-Review

**Spec coverage:**

- ✅ Replace Alloy heredoc → `toAlloyHCL` with `nestedBlock`/`ref` constructors
- ✅ Replace `builtins.toJSON` inline → typed dashboard builders
- ✅ `lib/generators.nix` is reusable for any future Alloy components
- ✅ `lib/dashboards.nix` makes adding new panels/dashboards trivial
- ✅ Unit tests in `checks` output
- ✅ Validated with `nix flake check` / `nix build`

**No placeholders:** all steps have complete code.

**Type consistency:**

- `gen.nestedBlock`, `gen.ref`, `gen.toAlloyHCL` — consistent throughout Tasks 1, 2, 6
- `dash.timeseriesPanel`, `dash.logsPanel`, `dash.target`, `dash.gridPos`, `dash.mimirDS`, `dash.lokiDS` — consistent throughout Tasks 3, 4, 6
- Parameter `ds` (not `datasource`) in panel builders — consistent in Tasks 3 and 6

---

**Plan complete and saved to `docs/superpowers/plans/2026-04-21-typed-alloy-grafana-generators.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
