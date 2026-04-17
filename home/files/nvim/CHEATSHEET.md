# Neovim Workflow Guide & Cheat Sheet

**Leader Key:** `Space`

This configuration is built for a keyboard-driven workflow. Instead of clicking through menus, you use "motions" and "fuzzy finding" to manipulate code and files.

---

## 1. The "How to Move" Philosophy

There are three ways to move in this setup, depending on where your target is:

1.  **If you know the name (Searching)**: Use **Telescope** to find files or text anywhere in the project.
2.  **If you see it on screen (Jumping)**: Use **Leap** to teleport your cursor to any visible character.
3.  **If it's nearby (Navigation)**: Use standard Vim motions (`w`, `b`, `j`, `k`) or **Oil** for directory-level moves.

### Searching (Telescope)
*When to use: Finding a file by name or searching for a specific string across the whole project.*

| Key | Action |
|-----|--------|
| `<leader>ff` | **Find Files**: Search by filename. |
| `<leader>fg` | **Live Grep**: Search for text inside all files. |
| `<leader>fb` | **Buffers**: Switch between open files. |
| `<leader>fh` | **Help**: Search Neovim documentation. |

**Inside Telescope:**
- `<CR>` : Open file.
- `<C-v>` / `<C-x>` : Open in **Vertical** / **Horizontal** split.
- `<C-t>` : Open in new **Tab**.

### Jumping (Leap)
*When to use: You see a word on line 40 and want to be there instantly. Much faster than hitting `jjj...`.*

| Key | Action |
|-----|--------|
| `s{char}{char}` | **Leap Forward**: Type `s` then the first two letters of your target. |
| `S{char}{char}` | **Leap Backward**: Same as above, but searches upwards. |
| `gs{char}{char}` | **Leap Remote**: Perform an action (like `d` or `y`) at a target without moving your cursor. |

### Filesystem Mastery (Oil)
*When to use: Instead of a sidebar, Oil lets you edit your folders like a text file. Want to rename 10 files? Just use find-and-replace on the filenames and save.*

| Key | Action |
|-----|--------|
| `-` or `<leader>e` | **Open Oil**: Opens the current directory as a buffer. |
| `<CR>` | Enter a directory or open a file. |
| `<C-p>` | **Preview**: See file content without opening it. |
| `g.` | Toggle **Hidden Files**. |
| `-` (inside Oil) | Go up to the parent directory. |
| `:w` (inside Oil) | **Save changes**: Renaming/deleting lines in Oil applies those changes to your disk. |

---

## 2. Intelligent Coding (LSP & Completion)

### Completion (blink.cmp)
*When to use: Suggestions appear automatically as you type. GitHub Copilot results are mixed in and "boosted" to the top.*

| Key | Action |
|-----|--------|
| `<C-Space>` | Manually trigger completion or toggle documentation. |
| `<Tab>` / `<S-Tab>` | Cycle suggestions or jump through snippet placeholders. |
| `<CR>` | Accept the selection. |
| `<C-e>` | Close the menu. |
| `<C-b>` / `<C-f>` | Scroll documentation up / down. |

### Code Intelligence (LSP)
*When to use: Understanding and refactoring code. These keys "know" your programming language.*

| Key | Action |
|-----|--------|
| `gd` | **Go to Definition**: Jump to where a variable/function is defined. |
| `gr` | **References**: See every place this symbol is used in the project. |
| `K`  | **Hover**: Show documentation for the symbol under cursor. |
| `<leader>lr` | **Rename**: Rename a variable everywhere in the project safely. |
| `<leader>la` | **Code Action**: Quick fixes (e.g., import a missing library). |
| `<leader>lf` | **Format**: Clean up indentation and style. |
| `<leader>lh` | **Inlay Hints**: Toggle inline parameter names. |

---

## 3. Managing Errors (Diagnostics & Trouble)

*When to use: When you see red/yellow underlines. "Trouble" provides a clean list of everything you need to fix.*

| Key | Action |
|-----|--------|
| `]d` / `[d` | Jump to the next/previous error in the current file. |
| `<leader>ld` | Show the full error message in a floating window. |
| `<leader>xx` | **Trouble**: Open a panel at the bottom with all project errors. |
| `<leader>xf` | **Buffer Diagnostics**: Only show errors for the current file. |
| `<leader>xq` | **Quickfix**: Toggle the native quickfix list. |

---

## 4. Structural Editing

### Treesitter Objects
*When to use: Don't select text character-by-character. Select "logical" blocks like whole functions or classes.*

- Use with `v` (visual), `d` (delete), `c` (change), or `y` (yank).
- `af` / `if` : **A**round / **I**nner **F**unction. (e.g., `vaf` selects the whole function).
- `ac` / `ic` : **A**round / **I**nner **C**lass.

### Folds (Treesitter)
*When to use: Hiding large blocks of code you aren't working on.*

| Key | Action |
|-----|--------|
| `zc` / `zo` | **Close** / **Open** a fold. |
| `za` | **Toggle** a fold. |
| `zM` / `zR` | **Close All** / **Open All** folds. |

### Surround (nvim-surround)
*Logic: `verb` + `target` + `surround-char`*

| Key | Action |
|-----|--------|
| `ysiw"` | **Add**: **Y**ou **S**urround **I**nner **W**ord with **"**. |
| `cs"'` | **Change**: **C**hange **S**urround **"** to **'**. |
| `ds"` | **Delete**: **D**elete **S**urround **"**. |

---

## 5. Git & Workspace

### Git Workflow
*When to use: Use Gitsigns for small changes (hunks) and Lazygit for commits/pushes.*

| Key | Action |
|-----|--------|
| `<leader>gg` | **Lazygit**: Full terminal UI for staging, committing, and branching. |
| `]c` / `[c` | Jump between changed chunks of code (hunks). |
| `<leader>hp` | **Preview Hunk**: See what you changed in a small popup. |
| `<leader>hs` | **Stage Hunk**: Stage only this specific change. |
| `<leader>hr` | **Reset Hunk**: Undo the changes in this specific block. |
| `<leader>hb` | **Blame**: See who last changed this line. |

### Session Management
*When to use: To pick up exactly where you left off when you restart Neovim.*

| Key | Action |
|-----|--------|
| `<leader>qs` | **Restore Session**: Reload all files/splits for this folder. |
| `<leader>ql` | **Last Session**: Restore whatever you were doing last, anywhere. |
| `<leader>qd` | **Don't Save**: Stop tracking session for this exit. |

---

## 6. Language Specifics

### LaTeX (Vimtex)
- `<leader>vc`: Start **Continuous Compilation**. Saves trigger a PDF rebuild.
- `<leader>vv`: **View**: Open the PDF at your current cursor location (SyncTeX).
- `<leader>vt`: **Table of Contents**: Open a side panel with the document structure.
- `<leader>lg`: Toggle **LTeX Grammar**: Real-time spell/grammar checking for prose.

### Python
- `<leader>r`: Run the current file immediately in a terminal.
- `<leader>tt`: Run the **nearest test**.
- `<leader>tT`: Run **all tests** in the current file.
- `<leader>ts` / `<leader>to`: Toggle **Summary** / **Output** panel.
- `<leader>tn` / `<leader>tp`: Jump to **Next** / **Previous** test.

---

## UI Toggles & Extras

| Key | Action |
|-----|--------|
| `<leader>ct` | Toggle **Copilot** on/off. |
| `<leader>un` | Show **Notification History** (via Snacks). |
| `<leader>m`  | **Markdown Preview** (via Glow). |
| `<C-\>` | Toggle a **Terminal** at the bottom. |
| `]]` / `[[` | Jump to the next/prev occurrence of the word under cursor. |
