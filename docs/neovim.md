# Neovim

This repo carries a Lua-first Neovim configuration installed through Home
Manager. It targets Neovim 0.11+ native LSP, `lazy.nvim`, fast completion, and a
keyboard-driven workflow.

Core pieces:

- `blink.cmp` for completion, including GitHub Copilot suggestions.
- `oil.nvim` for filesystem editing as a buffer.
- `leap.nvim` and `telescope.nvim` for navigation and search.
- Native LSP setup for `nixd`, `clangd`, `basedpyright`, and `ltex`.
- `nvim-dap`, `neotest`, and `conform` for debugging, tests, and formatting.
- Runtime theme integration with the Home Manager theme module.

Current implementation lives under `home/files/nvim/`. Detailed keymaps are in
`home/files/nvim/CHEATSHEET.md`.

The longer-term plan to turn this into a first-class configurable Home Manager
module is tracked in `docs/neovim-module.md`.
