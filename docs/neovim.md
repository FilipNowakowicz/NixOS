# Neovim

This repo carries a Lua-first Neovim configuration assembled by Home Manager. It
targets Neovim 0.11+ native LSP, `lazy.nvim`, fast completion, and a
keyboard-driven workflow without moving the day-to-day editor behavior into
Nix.

## Overview

Core pieces:

- `blink.cmp` for completion, including GitHub Copilot suggestions.
- `oil.nvim` for filesystem editing as a buffer.
- `leap.nvim` and `telescope.nvim` for navigation and search.
- Native LSP setup for `nixd`, `clangd`, `basedpyright`, and `ltex`.
- `nvim-dap`, `neotest`, and `conform` for debugging, tests, and formatting.
- Runtime theme integration with the Home Manager theme module.

Detailed keymaps are in `home/files/nvim/CHEATSHEET.md`.

## Layout

- `home/neovim/module.nix`
  Owns the `my.neovim` option surface, package ownership, generated artifacts,
  and final config assembly.
- `home/neovim/packs/`
  Language-pack definitions for Nix, Python, and TeX.
- `home/neovim/generators/lua-config.nix`
  Emits `lua/config/generated.lua`.
- `home/neovim/generators/cheatsheet.nix`
  Emits `CHEATSHEET.md` from the keymap registry.
- `home/files/nvim/`
  Handwritten Neovim runtime tree.
- `home/files/nvim/lua/config/keymap_registry.lua`
  Shared source for runtime mappings and the generated cheatsheet.

## Architecture

The split is:

- Lua runtime layer
  Owns startup, plugin setup, keymap callbacks, and runtime behavior.
- Nix module layer
  Owns feature selection, language-pack package installation, generated config
  data, and cheatsheet generation.

At build time the module assembles a normal `~/.config/nvim` tree from the
checked-in runtime files plus generated artifacts.

## Generated Config Contract

`home/neovim/module.nix` merges the enabled packs into one generated Lua table
consumed by the runtime modules.

That table currently carries:

- enabled languages and language-specific options
- enabled LSP servers and server settings
- formatter mappings
- linter mappings
- neotest adapter config
- DAP configurations
- project marker inventory

The main consumers are:

- `home/files/nvim/lua/config/lsp.lua`
- `home/files/nvim/lua/config/format.lua`
- `home/files/nvim/lua/config/lint.lua`
- `home/files/nvim/lua/config/tests.lua`
- `home/files/nvim/lua/config/dap.lua`

Those modules read generated data rather than hardcoding per-language policy in
multiple places.

## Keymaps And Cheatsheet

Runtime mappings are registered from
`home/files/nvim/lua/config/keymap_registry.lua`.

The Home Manager build generates `CHEATSHEET.md` from that same registry, so
the installed cheatsheet tracks the configured mappings instead of relying on a
separate handwritten inventory.

The cheatsheet is intentionally a compact reference sheet rather than a tutorial
document.

## Configuration Surface

The Home Manager surface is intentionally small and capability-oriented:

```nix
my.neovim = {
  enable = true;
  package = pkgs.neovim-unwrapped;

  cheatsheet.enable = true;
  projectDetection.enable = true;

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

Pack enablement drives both package installation and generated runtime data.

## Current Follow-Ups

The remaining Neovim work is refinement, not missing structure:

- `project_detection` is generated but not yet consumed by runtime modules for
  test or DAP defaults.
- Plugin inclusion is still mostly static; packs drive packages and generated
  data, but not much plugin selection yet.
