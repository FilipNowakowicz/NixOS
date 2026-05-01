# Neovim First-Class Module Design

Status: proposed

This document defines how to turn the existing checked-in Neovim setup into a first-class Home Manager module without migrating to `nixvim` and without replacing the current Lua-first workflow.

## Summary

The target state is:

- Keep `init.lua` and the existing Lua configuration layout.
- Keep `lazy.nvim` as the runtime plugin manager.
- Keep Neovim behavior primarily expressed in Lua.
- Use Nix as the declarative control plane for:
  - enabling editor features
  - selecting language packs
  - installing supporting binaries
  - generating small Lua data files
  - generating the Neovim cheatsheet

This is not a migration to `nixvim`, and it is not a migration to Home Manager's `programs.neovim` as the main configuration surface.

## Motivation

The current repository already has a strong Neovim setup, but Nix only knows how to copy it into place:

- `home/users/user/common.nix` exports the full `home/files/nvim` directory to `~/.config/nvim`
- editor packages are split between `home/profiles/base.nix` and `home/profiles/workstation.nix`
- language behavior is hardcoded in Lua
- the cheatsheet is handwritten

That is good enough for a single static setup, but it creates friction in four areas:

1. Changing a language workflow means editing several files by hand.
2. Different machines cannot easily share one Neovim setup with different feature levels.
3. The documentation can drift away from the real keymaps.
4. Nix cannot answer basic questions such as "which languages are enabled" or "which external tools does this editor configuration depend on."

## Goals

- Make Neovim configurable through a dedicated Home Manager module.
- Preserve the current Lua-first runtime model.
- Support per-machine and per-profile variation without forking the Neovim config.
- Group language-specific functionality into declarative packs.
- Generate machine-readable Lua config from Nix for use by runtime modules.
- Generate the cheatsheet from the actual keymap registry.
- Keep the migration incremental and reversible.

## Non-Goals

- Do not adopt `nixvim`.
- Do not port the entire Neovim configuration into pure Nix.
- Do not replace `lazy.nvim`.
- Do not aim for full support for every language up front.
- Do not generate every Lua file from Nix. Only policy and data should be generated.

## Constraints

The repo already documents a practical constraint in `home/users/user/common.nix`: Home Manager's `programs.neovim` path has packaging lag and conflicts with upstream plugin and Treesitter expectations. The design must respect that.

The module therefore needs to generate and install a normal `~/.config/nvim` tree while still allowing the raw Lua runtime to own editor behavior.

## Current State

Today the Neovim setup is composed like this:

- `home/profiles/base.nix`
  - installs core editor packages such as `neovim-unwrapped`, `nodejs`, `nixd`, `basedpyright`, `ruff`, `stylua`, `nixfmt`, `glow`
- `home/profiles/workstation.nix`
  - installs heavier desktop/editor tools such as `texlab` and `ltex-ls-plus`
- `home/users/user/common.nix`
  - exports `home/files/nvim` directly into `~/.config/nvim`
- `home/files/nvim/lua/config/plugins.lua`
  - defines the `lazy.nvim` plugin set
- `home/files/nvim/lua/config/lsp.lua`
  - hardcodes enabled LSP servers and settings
- `home/files/nvim/lua/config/format.lua`
  - hardcodes formatter mappings
- `home/files/nvim/lua/config/lint.lua`
  - hardcodes linter mappings
- `home/files/nvim/lua/config/tests.lua`
  - hardcodes Python `neotest` integration
- `home/files/nvim/lua/config/dap.lua`
  - hardcodes Python debug profile
- `home/files/nvim/CHEATSHEET.md`
  - is maintained by hand

## Proposed Architecture

### Design Principle

Split Neovim into two layers:

- Lua runtime layer
  - owns startup
  - owns plugin setup
  - owns keymaps
  - owns runtime behavior
- Nix module layer
  - owns feature selection
  - owns package installation
  - owns generated config data
  - owns generated documentation

This keeps the code you use daily in Lua, while moving policy and inventory into Nix.

### New Module

Add a new Home Manager module:

```text
home/neovim/module.nix
```

This module should:

- define the option surface for Neovim
- compute enabled language packs
- collect package requirements from those packs
- generate `lua/config/generated.lua`
- generate `CHEATSHEET.md`
- install the final `~/.config/nvim` tree through `xdg.configFile`

### Supporting Layout

Proposed layout:

```text
home/
  neovim/
    module.nix
    packs/
      nix.nix
      python.nix
      tex.nix
    generators/
      lua-config.nix
      cheatsheet.nix
  files/
    nvim/
      init.lua
      lua/config/
        options.lua
        plugins.lua
        keymaps.lua
        lsp.lua
        format.lua
        lint.lua
        tests.lua
        dap.lua
        tex.lua
```

The `home/files/nvim` tree remains the source for handwritten Lua. The `home/neovim` tree becomes the source for generated data and Nix-side assembly.

### Final Config Tree

The module should assemble a final `~/.config/nvim` directory from:

- static Lua files from `home/files/nvim`
- generated `lua/config/generated.lua`
- generated `CHEATSHEET.md`
- optionally generated helper files later

The assembled output should still look like a normal Neovim config directory to Neovim itself.

## Option Surface

The initial option surface should stay small and track real current use:

```nix
my.neovim = {
  enable = true;

  package = pkgs.neovim-unwrapped;

  ui = {
    themeIntegration = true;
    terminal = true;
    sessions = true;
    copilot = true;
  };

  projectDetection.enable = true;
  cheatsheet.enable = true;

  languages = {
    nix.enable = true;

    python = {
      enable = true;
      testRunner = "pytest";
      dap = true;
    };

    tex = {
      enable = true;
      grammar = true;
    };
  };
};
```

Notes:

- `my.neovim` is a placeholder namespace. If the repo has a preferred namespace later, this can change before implementation.
- The first version should avoid a deep option tree for every plugin. The point is to model capabilities, not every `lazy.nvim` knob.

## Language Pack Model

Each language pack should declare a small structured record with:

- external packages
- LSP servers
- formatter bindings
- linter bindings
- neotest adapters
- DAP configurations
- project markers
- optional keymap/doc sections

Example conceptual shape:

```nix
{
  packages = [ pkgs.basedpyright pkgs.ruff pkgs.python3 ];

  lsp = {
    basedpyright = {
      enable = true;
      settings = { ... };
    };
  };

  formatters = {
    python = [ "ruff_format" ];
  };

  linters = {
    python = [ "ruff" ];
  };

  tests = {
    adapters = [
      {
        plugin = "neotest-python";
        filetypes = [ "python" ];
        config = {
          runner = "pytest";
          dap.justMyCode = false;
        };
      }
    ];
  };

  dap = {
    python = [
      {
        name = "Launch file";
        type = "python";
        request = "launch";
        program = "\${file}";
      }
    ];
  };

  projectMarkers = [ "pyproject.toml" "pytest.ini" ".python-version" ];
}
```

The implementation does not need to expose all of this directly to users as options. Internally, though, the module should normalize enabled packs into one merged data structure.

## Generated Lua Contract

The key integration point is a generated Lua file:

```text
lua/config/generated.lua
```

This file should return a plain Lua table, for example:

```lua
return {
  languages = {
    nix = {
      enable = true,
    },
    python = {
      enable = true,
      test_runner = "pytest",
      dap = true,
    },
    tex = {
      enable = true,
      grammar = true,
    },
  },
  lsp = {
    enable = { "nixd", "basedpyright" },
    settings = {
      basedpyright = {
        basedpyright = {
          analysis = {
            typeCheckingMode = "basic",
          },
        },
      },
    },
  },
  formatters_by_ft = {
    python = { "ruff_format" },
    nix = { "nixfmt" },
    lua = { "stylua" },
  },
  linters_by_ft = {
    python = { "ruff" },
  },
  tests = {
    adapters = {
      {
        plugin = "neotest-python",
        config = {
          runner = "pytest",
          dap = { justMyCode = false },
        },
      },
    },
  },
  dap = {
    configurations = {
      python = {
        {
          name = "Launch file",
          type = "python",
          request = "launch",
          program = "${file}",
        },
      },
    },
  },
  project_detection = {
    enable = true,
    markers = {
      python = { "pyproject.toml", "pytest.ini" },
      nix = { "flake.nix", "shell.nix" },
      tex = { ".latexmkrc" },
    },
  },
}
```

The exact field names can change, but the contract should remain simple:

- one generated Lua table
- consumed by existing runtime modules
- no generated imperative startup logic

## Runtime Lua Changes

The Lua side should stay modular. The only design change is that the modules stop hardcoding policy and start reading from `config.generated`.

Target pattern:

- `plugins.lua`
  - keeps plugin definitions
  - may later conditionally include language plugins if needed
- `lsp.lua`
  - reads enabled servers and server settings from generated data
- `format.lua`
  - reads `formatters_by_ft`
- `lint.lua`
  - reads `linters_by_ft`
- `tests.lua`
  - reads test adapter config
- `dap.lua`
  - reads DAP profiles
- `keymaps.lua`
  - moves to a registry format that can also generate docs

The important boundary is:

- Nix may generate data tables
- Lua still decides how to apply them

## Keymap Registry and Cheatsheet

The current cheatsheet is a handwritten document. That creates obvious drift risk.

The new design should introduce a keymap registry that serves two purposes:

- register keymaps at runtime
- generate `CHEATSHEET.md` from the same source

### Proposed Registry Shape

Use a simple Lua table in `keymaps.lua` or a small `keymap_registry.lua` helper:

```lua
return {
  {
    mode = "n",
    lhs = "<leader>ff",
    rhs = function()
      require("telescope.builtin").find_files()
    end,
    desc = "Find files",
    section = "Searching",
  },
}
```

At runtime:

- Lua iterates the registry and calls `vim.keymap.set`

For docs:

- Nix reads a machine-readable export, or
- Lua maintains a doc-only table alongside runtime mappings, or
- the registry is defined in a generated format that both Lua and Nix can consume

The cleanest first implementation is likely:

- keep a lightweight Nix-side keymap manifest for documented mappings
- let Lua consume the same generated manifest for actual registration

That avoids needing Nix to parse arbitrary Lua.

### Generated Cheatsheet Scope

The first version should generate:

- key
- mode
- short description
- section

It does not need to regenerate the prose-heavy teaching content from the existing cheatsheet on day one. The first version can be a practical reference sheet.

## Project Detection

Project detection should be declarative and conservative.

Purpose:

- expose project-local context to runtime modules
- choose defaults without introducing hidden behavior

Examples:

- Python project markers
  - `pyproject.toml`
  - `pytest.ini`
  - `.venv/`
- Nix project markers
  - `flake.nix`
  - `shell.nix`
- TeX project markers
  - `.latexmkrc`
  - main `*.tex` buffer

The first version should only use project detection for:

- test runner defaults
- DAP defaults
- optional status or notifications later

It should not silently install or mutate anything at runtime.

## Package Ownership

The module should own all Neovim-related packages that are editor prerequisites.

That includes:

- `neovim-unwrapped`
- editor helper packages such as `lazygit`, `glow`, `tree-sitter`
- language tooling selected by enabled packs

Package ownership should move out of generic profiles where practical, so Nix can answer "what is required for this Neovim feature set" in one place.

Recommended split:

- keep truly general CLI tools in `home/profiles/base.nix`
- move editor-specific packages into `home/neovim/module.nix`

This should be done incrementally to avoid unrelated profile churn.

## Host and Profile Integration

The Neovim module should be enabled explicitly from user-level entrypoints.

Likely integration points:

- `home/users/user/home.nix`
- `home/users/user/wsl.nix`
- `home/users/user/server.nix`

Recommended policy:

- desktop profile
  - full language set
- WSL
  - same core editor, possibly fewer heavy language tools
- server
  - editor enabled, but avoid heavy desktop-only tooling

That gives one shared editor codebase with different pack selections.

## Plugin Management

Plugin installation remains in Lua with `lazy.nvim`.

Rationale:

- it matches the existing setup
- it keeps upstream plugin behavior intact
- it avoids the packaging lag called out in the current repo comments
- it keeps iteration on editor behavior fast

The module may eventually use generated data to include or exclude optional plugins, but the first implementation should keep the plugin list largely static to reduce migration risk.

## Migration Strategy

The migration should be phased.

### Phase 1: Introduce Module Without Behavior Change

- add `home/neovim/module.nix`
- move Neovim package ownership behind the module
- assemble the final config tree through the module
- keep the current Lua behavior unchanged

Acceptance criteria:

- `nvim` starts successfully
- same plugins load
- same keymaps work
- no user-visible workflow regressions

### Phase 2: Add Generated Lua Data

- add `lua/config/generated.lua`
- refactor `lsp.lua`, `format.lua`, `lint.lua`, `tests.lua`, `dap.lua` to read generated data
- encode current Python, Nix, and TeX behavior into the generated table

Acceptance criteria:

- no change in effective behavior
- the generated config is the single source of truth for language enablement

### Phase 3: Add Language Packs

- implement `packs/nix.nix`
- implement `packs/python.nix`
- implement `packs/tex.nix`
- merge pack outputs into the generated Lua contract

Acceptance criteria:

- pack enablement fully determines package installation and runtime config
- desktop, WSL, and server variants can select different pack sets cleanly

### Phase 4: Generated Cheatsheet

- introduce a keymap registry
- generate a concise `CHEATSHEET.md`
- remove drift between mappings and docs

Acceptance criteria:

- generated cheatsheet matches actual configured mappings
- no duplicated manual keymap inventory remains

### Phase 5: Project Detection

- add pack-level project markers
- expose detected context to runtime Lua
- use that context for test and DAP defaults

Acceptance criteria:

- project-aware behavior is predictable
- no hidden side effects beyond local runtime choices

## Implementation Plan

### Step 1: Create the Module Skeleton

Files:

- `home/neovim/module.nix`
- `home/neovim/generators/lua-config.nix`
- `home/neovim/generators/cheatsheet.nix`

Tasks:

- define `my.neovim.enable`
- install base editor packages through the module
- export the current static `home/files/nvim` tree
- reserve the generated file locations

### Step 2: Wire the Module Into User Entry Points

Files:

- `home/users/user/home.nix`
- `home/users/user/wsl.nix`
- `home/users/user/server.nix`

Tasks:

- import the module
- enable it in each user profile
- set pack selections appropriate to each profile

### Step 3: Generate Config Data

Files:

- `home/neovim/packs/nix.nix`
- `home/neovim/packs/python.nix`
- `home/neovim/packs/tex.nix`
- `home/files/nvim/lua/config/lsp.lua`
- `home/files/nvim/lua/config/format.lua`
- `home/files/nvim/lua/config/lint.lua`
- `home/files/nvim/lua/config/tests.lua`
- `home/files/nvim/lua/config/dap.lua`

Tasks:

- normalize enabled packs into one merged config object
- emit `generated.lua`
- switch runtime modules to consume generated data

### Step 4: Consolidate Keymaps

Files:

- `home/files/nvim/lua/config/keymaps.lua`
- optionally `home/files/nvim/lua/config/keymap_registry.lua`
- `home/neovim/generators/cheatsheet.nix`

Tasks:

- move mappings into a registry shape
- generate `CHEATSHEET.md`
- reduce manual duplication

### Step 5: Add Validation

Tasks:

- add a simple build target or check for generated config assembly
- verify Neovim startup in the existing VM or user environment
- ensure generated docs and Lua render reproducibly

## Validation Plan

At minimum, validate:

1. Home Manager evaluation succeeds for:
   - `.#user`
   - `.#user@wsl`
2. Generated files are present:
   - `~/.config/nvim/lua/config/generated.lua`
   - `~/.config/nvim/CHEATSHEET.md`
3. `nvim --headless "+qa"` succeeds
4. Current key workflows still function:
   - Telescope
   - LSP attach for Nix and Python
   - formatting
   - linting
   - Python tests
   - Python DAP
   - TeX workflow on a workstation profile

Future refinement:

- add a repo-local script that diffs generated cheatsheet entries against runtime registry data in CI

## Risks

### Risk 1: Over-modeling the editor in Nix

If the option surface gets too detailed too early, the module becomes harder to maintain than the raw Lua.

Mitigation:

- model only feature selection and data
- keep plugin internals in Lua

### Risk 2: Drift Between Generated Data and Runtime Expectations

If Lua expects shapes that Nix does not generate correctly, startup failures become harder to diagnose.

Mitigation:

- keep the generated contract small
- introduce it in a behavior-preserving phase

### Risk 3: Package Scope Sprawl

Moving packages into the Neovim module could accidentally absorb unrelated shell tooling.

Mitigation:

- move only clear editor dependencies
- leave general-purpose CLI tools in base profiles

### Risk 4: Documentation Generation Becoming More Complex Than the Docs

Auto-generated docs are only worth it if the generation source stays simple.

Mitigation:

- generate a practical reference sheet first
- keep prose-heavy tutorial content separate if needed

## Open Questions

- Should the module namespace be `my.neovim`, `modules.neovim`, or another repo-local convention?
- Should `server` and `wsl` share the full language set by default, or should they opt into lighter packs?
- Should plugin inclusion remain fully static in phase 1 through phase 3, or should some language plugins become conditional once pack support exists?
- Should the generated cheatsheet replace the existing narrative document entirely, or should the generated section become a concise appendix?

## Recommended First Slice

The best first implementation slice is:

- add the Home Manager module
- move Neovim package ownership under it
- generate `lua/config/generated.lua`
- convert Python, Nix, and TeX config to consume generated data
- leave plugin definitions mostly unchanged
- postpone project detection and advanced cheatsheet generation until after that lands

That slice gives real structure immediately while keeping migration risk low.
