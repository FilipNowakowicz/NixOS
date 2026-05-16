# Neovim Cheat Sheet

Generated from `lua/config/keymap_registry.lua`.

## Navigation

| Key         | Mode | Description           | Context |
| ----------- | ---- | --------------------- | ------- |
| `-`         | `n`  | Open parent directory |         |
| `<leader>e` | `n`  | File explorer         |         |

## Search

| Key          | Mode | Description | Context |
| ------------ | ---- | ----------- | ------- |
| `<leader>fb` | `n`  | Buffers     |         |
| `<leader>ff` | `n`  | Find files  |         |
| `<leader>fg` | `n`  | Live grep   |         |
| `<leader>fh` | `n`  | Help tags   |         |

## Editing

| Key         | Mode | Description               | Context |
| ----------- | ---- | ------------------------- | ------- |
| `<leader>m` | `n`  | Markdown preview          |         |
| `<leader>r` | `n`  | Run current file (python) |         |

## Git

| Key          | Mode | Description   | Context |
| ------------ | ---- | ------------- | ------- |
| `<leader>gg` | `n`  | Lazygit       |         |
| `<leader>hb` | `n`  | Blame line    |         |
| `<leader>hp` | `n`  | Preview hunk  |         |
| `<leader>hr` | `n`  | Reset hunk    |         |
| `<leader>hs` | `n`  | Stage hunk    |         |
| `[c`         | `n`  | Previous hunk |         |
| `]c`         | `n`  | Next hunk     |         |

## LSP

| Key          | Mode | Description          | Context    |
| ------------ | ---- | -------------------- | ---------- |
| `<leader>la` | `n`  | Code action          | LSP buffer |
| `<leader>lh` | `n`  | Toggle inlay hints   |            |
| `<leader>lr` | `n`  | Rename               | LSP buffer |
| `K`          | `n`  | Hover                | LSP buffer |
| `gD`         | `n`  | Go to declaration    | LSP buffer |
| `gd`         | `n`  | Go to definition     | LSP buffer |
| `gi`         | `n`  | Go to implementation | LSP buffer |
| `gr`         | `n`  | Go to references     | LSP buffer |

## Diagnostics

| Key          | Mode | Description           | Context |
| ------------ | ---- | --------------------- | ------- |
| `<leader>ld` | `n`  | Show diagnostics      |         |
| `<leader>lq` | `n`  | List diagnostics (qf) |         |
| `[d`         | `n`  | Previous diagnostic   |         |
| `]d`         | `n`  | Next diagnostic       |         |

## Testing

| Key          | Mode | Description  | Context |
| ------------ | ---- | ------------ | ------- |
| `<leader>tT` | `n`  | Test file    |         |
| `<leader>tl` | `n`  | Test last    |         |
| `<leader>tn` | `n`  | Next test    |         |
| `<leader>to` | `n`  | Test output  |         |
| `<leader>tp` | `n`  | Prev test    |         |
| `<leader>ts` | `n`  | Test summary |         |
| `<leader>tt` | `n`  | Test nearest |         |

## Debug

| Key          | Mode | Description                | Context |
| ------------ | ---- | -------------------------- | ------- |
| `<F10>`      | `n`  | DAP step over              |         |
| `<F11>`      | `n`  | DAP step into              |         |
| `<F12>`      | `n`  | DAP step out               |         |
| `<F5>`       | `n`  | DAP continue               |         |
| `<leader>dB` | `n`  | DAP conditional breakpoint |         |
| `<leader>db` | `n`  | DAP toggle breakpoint      |         |
| `<leader>dl` | `n`  | DAP run last               |         |
| `<leader>dr` | `n`  | DAP REPL                   |         |
| `<leader>du` | `n`  | DAP UI toggle              |         |

## Sessions

| Key          | Mode | Description        | Context |
| ------------ | ---- | ------------------ | ------- |
| `<leader>qd` | `n`  | Don't save session |         |
| `<leader>ql` | `n`  | Last session       |         |
| `<leader>qs` | `n`  | Restore session    |         |

## Trouble

| Key          | Mode | Description                | Context |
| ------------ | ---- | -------------------------- | ------- |
| `<leader>xf` | `n`  | Buffer diagnostics         |         |
| `<leader>xl` | `n`  | LSP references/definitions |         |
| `<leader>xq` | `n`  | Quickfix list              |         |
| `<leader>xx` | `n`  | Diagnostics                |         |

## UI

| Key          | Mode | Description          | Context |
| ------------ | ---- | -------------------- | ------- |
| `<C-\>`      | `n`  | Toggle terminal      |         |
| `<leader>ct` | `n`  | Toggle Copilot       |         |
| `<leader>un` | `n`  | Notification history |         |
| `[[`         | `n`  | Prev word occurrence |         |
| `]]`         | `n`  | Next word occurrence |         |
| `gs`         | `n`  | Leap remote          |         |

## LaTeX

| Key          | Mode | Description         | Context                     |
| ------------ | ---- | ------------------- | --------------------------- |
| `<leader>lg` | `n`  | Toggle LTeX grammar | when TeX grammar is enabled |
| `<leader>vc` | `n`  | Compile             | tex/plaintex buffer         |
| `<leader>vt` | `n`  | TOC                 | tex/plaintex buffer         |
| `<leader>vv` | `n`  | View PDF            | tex/plaintex buffer         |
| `<leader>vz` | `n`  | Toggle conceal      | tex/plaintex buffer         |
