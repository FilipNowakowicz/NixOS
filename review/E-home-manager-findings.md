# Home Manager Review — Findings

Domain: `home/` directory of the NixOS flake. Focus: things that evaluate and
build cleanly but are wrong, dead, redundant, or missing in practice.

Severity legend:

- **P0** — silent failure / broken / dead config that the author believes is active
- **P1** — significant gap or security/correctness issue
- **P2** — optimization / redundancy
- **P3** — future addition

---

## P0 — Silent failures and dead config

### P0.1 — Theme system does not propagate to Neovim (hardcoded gruvbox-material)

- `home/files/nvim/lua/config/ui.lua:1-3` hardcodes `gruvbox-material` as the colorscheme.
- `home/theme/module.nix` themes kitty, hyprland, hyprlock, waybar, mako — **but never neovim**.

The theme module advertises (option doc, `module.nix:188-191`) that switching the
active theme re-themes the desktop. In practice, the terminal background, borders,
and bars change, but the editor that fills the terminal stays gruvbox-material for
**all 8 themes**. On light-ish palettes (e.g. `cold-concrete` text `d7e1df` on bg
`06090d`, or `lunar-peaks`) the mismatch between the gruvbox editor and the themed
terminal chrome is very visible. This is the single biggest "theme doesn't actually
propagate" gap.

Fix direction: generate a neovim color file from `themes._activeThemeColors`
(already exposed as an internal option, `module.nix:195-199`) and `source` it from
the generated lua, OR set the kitty/terminal `background`/`foreground` and let
neovim inherit via a minimal `colorscheme` that uses terminal colors
(`vim.cmd.colorscheme("default")` won't honor it cleanly — better to emit a tiny
generated highlight file). At minimum, drive `vim.o.background` and the
gruvbox-material `background`/`foreground` knobs from the active theme so dark/light
intent is correct.

### P0.2 — Kitty palette ignores the active theme (hardcoded gruvbox ANSI 16)

- `home/theme/module.nix:111-128`. `color1..color6`, `color9..color14` are
  hardcoded gruvbox hex (`#cc241d`, `#98971a`, `#458588`, …) for **every** theme.

Only `bg`, `brown`, `amber`, `text` are theme-driven; the actual ANSI palette that
TUIs (lazygit, btop, fastfetch, neovim's `:terminal`, colored `ls`/`bat`) render
with is gruvbox regardless of the selected theme. So "switch theme" leaves all
16-color TUI output looking gruvbox. Either derive the ANSI ramp from the theme's
5 colors, or define a full 16-color block per theme in `themes/*.nix`.

### P0.3 — `texlab` LSP is installed but never started

- `home/neovim/packs/tex.nix:7` puts `texlab` on `home.packages` (PATH).
- `home/neovim/packs/tex.nix:9-12` sets `lsp.enable = [ ]` (empty).
- `home/files/nvim/lua/config/lsp.lua:10-22` only enables servers from
  `generated.lsp.enable`, so texlab is **never** passed to `vim.lsp.enable`.

Result: in `.tex` buffers you get vimtex (compile/view) and optional LTeX (grammar,
manual start), but **no texlab**: no completion of `\ref`/`\cite`/labels via LSP, no
go-to-definition, no document symbols, no diagnostics from texlab. The binary is
shipped but dead. Fix: `lsp.enable = [ "texlab" ];` in `tex.nix` (and optionally
texlab `settings`). vimtex's omni source partly overlaps but is not a substitute.

### P0.4 — `clangd` LSP is enabled unconditionally with no matching pack/package

- `home/files/nvim/lua/config/lsp.lua:8,10` hardcode `clangd` as an always-on server.
- There is **no C/C++ neovim pack**; `clangd` is provided only by `clang-tools` in
  `home/users/user/home.nix:291`, which is gated behind `!skipHeavyPackages`.

Consequences: (a) on any context where `clang-tools` is absent (CI `main-ci`,
`skipHeavyPackages`, or a future host without the workstation block), nvim tries to
start a `clangd` that isn't on PATH — it fails silently per buffer. (b) C tooling is
inconsistent with the pack model used for nix/python/tex: there's no `packs/c.nix`,
no formatter, no project markers, but treesitter still force-installs the `c` parser
(`ui.lua:27`). Fix: introduce a proper `c` pack (`clang-tools` in its `packages`,
`clangd` in `lsp.enable`, `clang-format` formatter) gated by a
`my.neovim.languages.c.enable` option, and remove the hardcoded clangd from lsp.lua.

### P0.5 — `workstation` profile is completely dead code

- `home/profiles/workstation.nix` provides `input-leap` + an `input-server` alias.
- `flake/hosts.nix:23-26` and `lib/hosts.nix:46-49` register `workstation` as a
  selectable HM profile, but **no host lists it** in `homeManager.profiles`
  (`main` and `mac` both use `profiles = [ "desktop" ]`).
- `main` already declares `input-leap` directly in `home/users/user/main.nix:4`.

So `workstation.nix` is never imported by any configuration. The comment in
`lib/hosts.nix:226` ("the workstation dev-tool block from home.nix is preserved")
is misleading — there is no workstation pack applied to mac; the dev tools come from
`home.nix`'s `!skipHeavyPackages` block, not from `workstation.nix`. Fix: either
wire `workstation` into `main`'s (and mac's) `homeManager.profiles` and move
`input-leap` there to deduplicate, or delete `workstation.nix` and its registry
plumbing.

### P0.6 — GTK theme never set; desktop GTK apps are unthemed

- `home/profiles/desktop.nix:82-86` enables GTK and forces dark-prefer, but sets no
  `gtk.theme`. `home/users/user/home.nix:321` sets `gtk.gtk4.theme = null`.
- `modules/nixos/profiles/desktop.nix:63` installs `gnome-themes-extra` (the usual
  source of an Adwaita-dark/`Adwaita-dark` GTK theme) but nothing references it.

Effect: thunar, pavucontrol, blueman, the GTK file chooser, and any GTK app fall
back to the stock light Adwaita with only the `prefer-dark` hint. They are not part
of the theme system at all and don't even reliably go dark for GTK3 apps that ignore
libadwaita's color-scheme. Fix: set `gtk.theme = { name = "Adwaita-dark"; package =
pkgs.gnome-themes-extra; }` (move that package to HM), or generate a per-theme GTK
colors via a libadwaita/gtk-css override and link it from the theme module.

---

## P1 — Gaps and correctness

### P1.1 — Treesitter parser compilation needs a C compiler that may be absent

- `home/files/nvim/lua/config/plugins.lua:139` (`build = ":TSUpdate"`) and
  `ui.lua:27` (`ensure_installed` of 6 parsers) compile parsers at runtime with a
  C compiler.
- `gcc`/`gnumake` are only in `home/users/user/home.nix:285-302` under
  `!skipHeavyPackages`, and `telescope-fzf-native` (`plugins.lua:150`, `build =
"make"`) needs `make` + a compiler too.

On the real workstation this happens to work (gcc is in the heavy block), but the
neovim module declares no compiler dependency of its own. A neovim-only context
(wsl is fine because it pulls the same `home.nix`? — no: wsl imports `common.nix`
only, **not** `home.nix`, so on WSL there is no gcc/make and treesitter/fzf-native
builds fail silently). Fix: add `gcc`/`gnumake` (or `stdenv.cc`) to the neovim
module's `home.packages` so treesitter and fzf-native always have a toolchain
wherever neovim is enabled.

### P1.2 — WSL gets a desktop-oriented Neovim but no build toolchain or LSP heavy bits

- `home/users/user/wsl.nix` → `common.nix` → `base.nix` + `neovim/module.nix`, with
  `my.neovim.enable` defaulting true and nix/python packs default-on.
- nix pack (`nixd`, `nixfmt`) and python pack (`basedpyright`, `ruff`) packages come
  via `packPackages` into `home.packages`, so those LSPs work on WSL. **But** no
  `gcc`/`make` (see P1.1) → treesitter highlight and telescope-fzf-native silently
  fail on first run. Also `MANPAGER = "nvim +Man!"` and `EDITOR=nvim` are set in
  `base.nix` for WSL, which is fine.

Fix overlaps with P1.1 (ship a compiler from the neovim module).

### P1.3 — `pull.ff = "only"` plus `gl = "git pull"` will reject normal pulls

- `home/profiles/base.nix:39` sets `pull.ff = "only"`; `home/users/user/common.nix:57`
  aliases `gl = "git pull"`.

Whenever local and remote have diverged, `gl` aborts with "Not possible to
fast-forward". That's an intentional safety choice, but there is no `gl`-equivalent
for `--rebase`. Minor, but worth a `glr = "git pull --rebase"` alias to make the
common case ergonomic given the ff-only default.

### P1.4 — `command_not_found` UX is split-brained vs system `nix-index`

- `home/profiles/base.nix:159-203` defines a `command_not_found_handle(r)` that
  shells out to `/run/current-system/sw/bin/nix-locate`.
- `modules/nixos/profiles/desktop.nix:5-11` sets `command-not-found.enable = false`
  and `nix-index.enableZshIntegration = true`, which **also** installs a
  `command_not_found_handler`.

On `main` the HM zsh `initContent` runs after nix-index's integration, so the HM
handler wins — acceptable. But: (a) the hardcoded `/run/current-system/...` path is
wrong for non-NixOS HM contexts (standalone `homeConfigurations.user`,
`user@wsl`), where there is no `/run/current-system`; the handler then always prints
"command not found" with a confusing exit path. (b) This is desktop/system policy
leaking into base HM. Fix: resolve `nix-locate` via `command -v nix-locate` with a
fallback, or gate the handler on its availability.

### P1.5 — Standalone `homeConfigurations.user` imports the desktop role without the desktop profile

- `flake/hosts.nix:136-148` builds `homeConfigurations.user` from
  `home/users/user/home.nix` directly, with **no** `desktop.nix` profile.
- `home.nix` itself pulls in hyprland/waybar/hyprlock/mako scripts and the theme
  module, but kitty, firefox, the GUI apps, GTK, cursor, mimeApps live in
  `desktop.nix` (the profile), which is only composed for NixOS hosts via
  `mkHomeManagerImports`.

Result: the standalone `user` HM config is a half-desktop: waybar/hypr theming and
scripts but no terminal/browser/file-manager and no GTK/cursor. If this entrypoint
is meant to be used (e.g. on a non-NixOS Linux box), it is broken/partial; if it
isn't used, it's dead surface that will bit-rot. Clarify intent: either add
`desktop.nix` (+ workflow packs) to its module list or drop the standalone `user`
config.

### P1.6 — `firefox-private` and the firefox profile diverge silently

- `home/users/user/home.nix:272-281` builds a `firefox-private` wrapper from a
  separate `private-user.js` (`home/files/firefox/private-user.js`).
- The themed/main firefox profile (`desktop.nix:58-79`) sets VA-API + memory prefs
  but **not** the private hardening prefs, and vice versa.

Two independent firefox config sources that don't share the VA-API decode settings
means private-mode firefox likely loses hardware video decode (CPU-bound playback),
and the main profile lacks the hardening. Worth reconciling: layer the VA-API prefs
into `private-user.js` too, or generate both from one shared pref set.

---

## P2 — Redundancy and level issues

### P2.1 — `bat` themed via base16 but no base16 theme provisioned

- `home/profiles/base.nix:93-99` sets `programs.bat.config.theme = "base16"`.
  `base16` is a builtin bat theme that maps to the terminal's ANSI 16 colors — which,
  per P0.2, are hardcoded gruvbox. So bat is "themed" but to a fixed gruvbox-ish ramp
  regardless of the active theme. Consistent only once P0.2 is fixed. (Not a bug on
  its own, but it's the consumer that makes P0.2 user-visible.)

### P2.2 — `mako` config managed twice (and a third stale copy)

- `home/users/user/home.nix:387-391` sets `services.mako.enable = true` and the
  comment says config is owned by the theme module.
- `home/theme/module.nix:155-171` writes per-theme `mako-config` and symlinks it.
- `home/files/scripts/theme-switch.sh:152` **also** contains an inline mako config
  block (`font=JetBrainsMono Nerd Font 11` …) — a third source of truth that can
  drift from the theme module's mako template. Consolidate.

### P2.3 — `input-leap` declared per-host instead of in a shared pack

- `home/users/user/main.nix:4` and `home/users/user/mac.nix:9` both list
  `input-leap`; `workstation.nix` (dead, P0.5) lists it a third time. Pick one home
  for it (the now-dead workstation profile is the natural one if revived).

### P2.4 — `hypridle` package added twice

- `home/users/user/home.nix:283` adds `hypridle` to `home.packages` **and**
  `home.nix:398-423` enables `services.hypridle` (which already brings the package
  and a systemd unit). The explicit package entry is redundant; the service is the
  source of truth.

### P2.5 — `waybar`, `kitty`, `swaybg`, `hyprland` duplicated between packages and theme-switch runtimeInputs

- `home/users/user/home.nix:156-167` lists waybar/hyprland/kitty/swaybg as
  `theme-switch` `runtimeInputs`, and they're also in `desktop.nix`'s `home.packages`.
  This is correct (runtimeInputs pins versions for the script) but worth noting it's
  intentional duplication, not a bug.

### P2.6 — `fonts` are system-level only; fontconfig not configured in HM

- Fonts live in `modules/nixos/profiles/desktop.nix:66-77` (correct for a shared
  font dir). But there's no HM `fonts.fontconfig` default-family mapping, so apps
  that query "monospace"/"sans-serif" get whatever fontconfig defaults to rather
  than JetBrainsMono Nerd / Inter that the rest of the desktop standardizes on.
  Consider an HM `fonts.fontconfig.defaultFonts` to make the choice explicit
  (P3-ish).

---

## P3 — Future additions worth implementing

- **P3.1 Theme→Neovim/GTK/Firefox bridge.** The cleanest fix for P0.1/P0.2/P0.6:
  treat `themes._activeThemeColors` as the single palette and generate (a) a neovim
  highlight/`base16`-style colorscheme, (b) a GTK/libadwaita color css, (c) a
  firefox `userChrome`/theme. Then "theme-switch" actually re-skins everything.
- **P3.2 `nvim-lspconfig`-free server settings for texlab** with chktex diagnostics
  once P0.3 lands.
- **P3.3 A `c`/`cpp` neovim pack** (P0.4) and optionally `go`/`rust`/`bash`/`json`
  packs to match the language-pack architecture already in place.
- **P3.4 `direnv` is enabled** (`home.nix:334-338`) but there's no `nix-direnv`
  integration declared; HM's `programs.direnv.nix-direnv.enable = true` gives much
  faster, cached `use flake`. Worth enabling.
- **P3.5 GPG/secret-service**: SSH agent is handled, but there's no
  `gnome-keyring`/secret-service wiring in HM for app credential storage (keepassxc
  is installed; consider its secret-service integration).
- **P3.6 `programs.git` lacks `rerere`, `diff.algorithm`, `merge.conflictStyle =
zdiff3`, and a global `core.excludesFile`** — standard productivity defaults for a
  daily driver.
- **P3.7 Clipboard manager**: `cliphist` is wired for Wayland, but neovim
  `clipboard=unnamedplus` (`options.lua:13`) on WSL has no `wl-copy`/`xclip`
  provider in `common.nix` → yank-to-system-clipboard silently no-ops on WSL.
  Add `wl-clipboard`/`win32yank` for the WSL context.
- **P3.8 `programs.neovim` not used**: the module ships config via raw
  `xdg.configFile` + `neovim-unwrapped`. That's a deliberate "lua-first" choice, but
  it forgoes HM's `extraPackages` (clean PATH scoping for LSPs) and the wrapped
  `nvim`. Consider `programs.neovim.extraPackages = packPackages` so LSP servers are
  scoped to neovim instead of polluting the global session PATH.
