# Neovim Cheat Sheet

Leader key: `Space`

---

## Completion (blink.cmp)

| Key | Action |
|-----|--------|
| `<C-Space>` | Open completion / toggle docs |
| `<Tab>` / `<S-Tab>` | Next / prev item, or jump snippet placeholder |
| `<C-n>` / `<C-p>` | Next / prev item |
| `<CR>` or `<C-y>` | Accept selected item |
| `<C-e>` | Cancel completion |
| `<C-b>` / `<C-f>` | Scroll documentation up / down |

Copilot suggestions appear as completion items (score-boosted). They don't show as inline ghost text — look in the completion menu.

---

## LSP

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gi` | Go to implementation |
| `gr` | Go to references |
| `K` | Hover documentation |
| `<leader>lr` | Rename symbol |
| `<leader>la` | Code action |
| `<leader>lf` | Format buffer / selection |
| `<leader>lh` | Toggle inlay hints |
| `<leader>ld` | Show diagnostics for current line (float) |
| `<leader>lq` | Send all diagnostics to quickfix |
| `[d` / `]d` | Previous / next diagnostic |
| `<leader>lg` | Toggle LTeX grammar checker (LaTeX / prose) |

Active servers: `clangd` (C/C++), `basedpyright` (Python), `nixd` (Nix), `ltex` (opt-in).

---

## Diagnostics & Trouble

| Key | Action |
|-----|--------|
| `<leader>xx` | Toggle Trouble — workspace diagnostics |
| `<leader>xf` | Toggle Trouble — current buffer only |
| `<leader>xl` | Toggle Trouble — LSP references / definitions panel |
| `<leader>xq` | Toggle Trouble — quickfix list |

---

## Fuzzy Finding (Telescope)

| Key | Action |
|-----|--------|
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep (search file contents) |
| `<leader>fb` | Open buffers |
| `<leader>fh` | Help tags |

**Inside Telescope:**

| Key | Action |
|-----|--------|
| `<C-n>` / `<C-p>` | Next / prev result |
| `<CR>` | Open in current window |
| `<C-x>` | Open in horizontal split |
| `<C-v>` | Open in vertical split |
| `<C-t>` | Open in new tab |
| `<Esc>` | Close |

---

## File Navigation (Oil)

Oil lets you edit the filesystem like a buffer — rename/delete/move by editing lines.

| Key | Action |
|-----|--------|
| `-` or `<leader>e` | Open Oil (parent directory of current file) |
| `<CR>` | Enter directory / open file |
| `-` (in Oil) | Go up one directory |
| `<C-s>` | Open in horizontal split |
| `<C-v>` | Open in vertical split |
| `<C-p>` | Preview file |
| `g.` | Toggle hidden files |

---

## Motion (Leap)

Leap lets you jump anywhere on screen with 2-character labels.

| Key | Action |
|-----|--------|
| `s{char}{char}` | Leap forward — jump to match |
| `S{char}{char}` | Leap backward |
| `gs{char}{char}` | Leap remote — run an action at the target position without moving cursor |

---

## Git (Gitsigns + Fugitive + Lazygit)

| Key | Action |
|-----|--------|
| `<leader>gg` | Open Lazygit (floating terminal) |
| `]c` / `[c` | Next / prev hunk |
| `<leader>hs` | Stage hunk |
| `<leader>hr` | Reset hunk |
| `<leader>hp` | Preview hunk inline |
| `<leader>hb` | Blame current line |

Fugitive (`:G`, `:Gdiff`, `:Gclog`, etc.) is also available for anything Lazygit doesn't cover.

---

## Debugging (nvim-dap + dap-ui)

The UI opens/closes automatically on launch and exit. Python uses the system `python3`.

| Key | Action |
|-----|--------|
| `<F5>` | Continue / start |
| `<F10>` | Step over |
| `<F11>` | Step into |
| `<F12>` | Step out |
| `<leader>db` | Toggle breakpoint |
| `<leader>dB` | Set conditional breakpoint (prompts for expression) |
| `<leader>dr` | Open REPL |
| `<leader>dl` | Re-run last debug session |
| `<leader>du` | Toggle dap-ui manually |

---

## Testing (Neotest — pytest)

| Key | Action |
|-----|--------|
| `<leader>tt` | Run nearest test |
| `<leader>tT` | Run all tests in current file |
| `<leader>tl` | Re-run last test |
| `<leader>ts` | Toggle test summary panel |
| `<leader>to` | Toggle test output panel |
| `<leader>tn` / `<leader>tp` | Jump to next / prev test |

---

## Terminal (toggleterm)

| Key | Action |
|-----|--------|
| `<C-\>` | Toggle horizontal terminal (15 lines) |
| `<leader>gg` | Open Lazygit in a floating terminal |

Inside a toggleterm terminal, `<C-\>` closes it. You can open multiple terminals by calling `:ToggleTerm id=2` etc.

---

## Session (persistence.nvim)

Sessions are saved per working directory.

| Key | Action |
|-----|--------|
| `<leader>qs` | Restore session for current directory |
| `<leader>ql` | Restore the last session (regardless of directory) |
| `<leader>qd` | Don't save a session when quitting |

---

## Editing Utilities

### Surround (nvim-surround)

| Key | Action |
|-----|--------|
| `ys{motion}{char}` | Add surround — e.g. `ysiw"` wraps word in `"` |
| `cs{old}{new}` | Change surround — e.g. `cs"'` changes `"` to `'` |
| `ds{char}` | Delete surround — e.g. `ds(` removes `()` |
| `yss{char}` | Surround entire line |
| `S{char}` (visual) | Surround selection |

### Commenting (Comment.nvim)

| Key | Action |
|-----|--------|
| `gcc` | Toggle line comment |
| `gbc` | Toggle block comment |
| `gc{motion}` | Comment over motion — e.g. `gcap` comments a paragraph |
| `gcO` / `gco` / `gcA` | Add comment above / below / at end of line |

### Pairs (nvim-autopairs)

Pairs `(`, `[`, `{`, `"`, `'` automatically. In `.tex`/`.plaintex`, `$` auto-pairs for inline math (won't pair if already inside `$...$` or if next char is `$`).

---

## Treesitter — Text Objects & Selection

### Text Objects (use with `d`, `c`, `v`, `y`, etc.)

| Key | Selects |
|-----|---------|
| `af` / `if` | Outer / inner function |
| `ac` / `ic` | Outer / inner class |

### Incremental Selection

| Key | Action |
|-----|--------|
| `gnn` | Start selection at cursor node |
| `grn` | Expand to next node |
| `grc` | Expand to enclosing scope |
| `grm` | Shrink selection back |

### Folds

Uses native treesitter fold expression. Folds are off by default.

| Key | Action |
|-----|--------|
| `zc` | Close fold under cursor |
| `zo` | Open fold under cursor |
| `za` | Toggle fold |
| `zM` | Close all folds |
| `zR` | Open all folds |

### Context

`nvim-treesitter-context` shows the current function/class/block in a sticky header at the top of the window (max 3 lines).

---

## LaTeX (vimtex — active in `.tex` / `.plaintex`)

Compiler: latexmk → PDF, output in `./build/`. Viewer: zathura with SyncTeX (forward/inverse search).
Spell checking (`en_gb`), soft-wrap, and `conceallevel=2` are set automatically.

| Key | Action |
|-----|--------|
| `<leader>vc` | Start / stop continuous compilation |
| `<leader>vv` | Forward-sync: open PDF at current cursor position |
| `<leader>vt` | Open table of contents |
| `<leader>vz` | Toggle conceal (0 ↔ 2) |
| `<leader>lg` | Toggle LTeX grammar LSP |

---

## UI & Miscellaneous

| Key | Action |
|-----|--------|
| `]]` / `[[` | Jump to next / prev occurrence of word under cursor (Snacks.words) |
| `<leader>un` | Show notification history |
| `<leader>ct` | Toggle Copilot on / off |
| `<leader>r` | Run current Python file (`:!python %`) |
| `<leader>m` | Markdown preview in terminal (Glow) |

### which-key

Press `<leader>` and wait — which-key shows all available bindings with group labels:

| Prefix | Group |
|--------|-------|
| `<leader>c` | Copilot |
| `<leader>d` | Debug |
| `<leader>f` | Find |
| `<leader>g` | Git |
| `<leader>h` | Hunk |
| `<leader>l` | LSP |
| `<leader>q` | Session |
| `<leader>t` | Test |
| `<leader>u` | UI |
| `<leader>v` | LaTeX |
| `<leader>x` | Trouble |
