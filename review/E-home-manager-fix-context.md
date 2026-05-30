# Home Manager — Fix Context (self-contained prompt for a fix agent)

You are fixing the Home Manager layer of a NixOS flake at the repo root. All
changes are `.nix` (and a few `.lua` config files under `home/files/nvim`). After
each change, validate with the commands listed per item. The repo's umbrella gates:

```bash
bash scripts/validate.sh flake-eval   # nix flake check --no-build (fast)
bash scripts/validate.sh host main     # build main closure (HM included)
statix check . && deadnix .
```

Neovim lua is not nix-evaluated; to sanity-check it, build `main` (which assembles
the generated config) and optionally run `nvim --headless "+checkhealth" +qa` on a
host. Themes: there are 8 under `home/theme/themes/*.nix`, each exposing
`colors = { bg; brown; orange; amber; text; }` and a `wallpaper`.

## Current Status

- `[DONE]` FIX 1, FIX 2, FIX 3, FIX 4, FIX 5, FIX 6, FIX 7, and FIX 9 landed.
  Standalone `homeConfigurations.user` now also imports the desktop profile.
- `[DONE]` FIX 8 landed by building `telescope-fzf-native`/Treesitter support
  without depending on a workstation-only C compiler.
- `[OPEN]` FIX 10, FIX 11, FIX 12, and FIX 13 remain open.

---

## FIX 1 (P0.3) — Enable the texlab LSP

File: `home/neovim/packs/tex.nix`

Current:

```nix
  lsp = {
    enable = [ ];
    settings = { };
  };
```

texlab is already on PATH (`packages = [ pkgs.texlab ] ++ ...`) but lsp.lua only
starts servers in `generated.lsp.enable`, so texlab never runs.

Fix:

```nix
  lsp = {
    enable = [ "texlab" ];
    settings = {
      texlab = {
        texlab = {
          build = { onSave = false; };
          chktex = { onOpenAndSave = true; };
        };
      };
    };
  };
```

(Match the nested-`settings` shape used in `packs/python.nix`, which double-nests
under the server name; verify against how `lsp.lua` line 13-17 merges
`server_settings` into `{ settings = ... }`. If python's nesting is one level too
deep there too, mirror whatever python does so it stays consistent.)

Validate:

```bash
bash scripts/validate.sh flake-eval
bash scripts/validate.sh host main
# then on a host: open a .tex file, :LspInfo should show texlab attached
```

---

## FIX 2 (P0.4) — Make C tooling a proper pack; stop hardcoding clangd

Files: new `home/neovim/packs/c.nix`, `home/neovim/module.nix`,
`home/files/nvim/lua/config/lsp.lua`.

`lsp.lua` currently hardcodes:

```lua
vim.lsp.config("clangd", { capabilities = capabilities })
local enabled_servers = { "clangd" }
```

This starts clangd even when `clang-tools` isn't installed (CI/`skipHeavyPackages`),
and there is no pack for C.

Step 1 — new pack `home/neovim/packs/c.nix`:

```nix
{ pkgs }:
{
  packages = with pkgs; [ clang-tools ];
  lsp = {
    enable = [ "clangd" ];
    settings = { };
  };
  formatters = { c = [ "clang_format" ]; cpp = [ "clang_format" ]; };
  linters = { };
  tests.adapters = [ ];
  dap = { };
  projectMarkers = {
    c = [ "compile_commands.json" "Makefile" "CMakeLists.txt" ".clangd" ];
  };
}
```

Step 2 — `home/neovim/module.nix`: add a `languages.c.enable` option (mirror
`languages.nix`), and include it in `enabledPacks`:

```nix
++ lib.optional cfg.languages.c.enable (import ./packs/c.nix { inherit pkgs; })
```

and in `languageConfig`:

```nix
c = { inherit (cfg.languages.c) enable; };
```

Step 3 — `home/files/nvim/lua/config/lsp.lua`: delete the two hardcoded clangd
lines so all servers (including clangd) flow through `generated.lsp.enable`:

```lua
-- remove:
-- vim.lsp.config("clangd", { capabilities = capabilities })
-- local enabled_servers = { "clangd" }
local enabled_servers = {}
```

Step 4 — wire `languages.c.enable` on the workstation. In
`home/users/user/home.nix`, near the existing tex language block (line ~316),
default it to the presence of the coding pack or true:

```nix
my.neovim.languages.c.enable = lib.mkDefault true;
```

(Or gate on `!skipHeavyPackages` if you want CI to skip it.)

Validate:

```bash
bash scripts/validate.sh flake-eval
bash scripts/validate.sh host main
bash scripts/validate.sh host main-ci   # confirm clangd no longer dangles in CI
statix check . && deadnix .
```

---

## FIX 3 (P1.1 / P1.2 / P1.7) — Ship a C toolchain from the neovim module

File: `home/neovim/module.nix`, `config.home.packages` (line ~147).

Treesitter `:TSUpdate` and `telescope-fzf-native` (`build = "make"`) compile at
runtime and need cc + make. Today they only work because the workstation's
`!skipHeavyPackages` block in `home.nix` happens to bring gcc/gnumake; WSL
(`common.nix` only) has neither, so highlighting and fuzzy finding silently break.

Current:

```nix
    home.packages = [
      cfg.package
      pkgs.glow
      pkgs.lazygit
      pkgs.stylua
      pkgs.tree-sitter
    ]
    ++ packPackages;
```

Fix:

```nix
    home.packages = [
      cfg.package
      pkgs.glow
      pkgs.lazygit
      pkgs.stylua
      pkgs.tree-sitter
      pkgs.gcc
      pkgs.gnumake
    ]
    ++ packPackages;
```

Then drop the now-redundant `gcc`/`gnumake` from `home/users/user/home.nix:289-291`
if neovim is always enabled on workstation hosts (it is, via `common.nix`
`my.neovim.enable = lib.mkDefault true`).

Validate:

```bash
bash scripts/validate.sh flake-eval
nix build .#homeConfigurations.\"user@wsl\".activationPackage   # exercises wsl path
bash scripts/validate.sh host main
```

---

## FIX 4 (P0.5 / P2.3) — Resolve the dead `workstation` profile

Files: `lib/hosts.nix`, `home/users/user/main.nix`, `home/users/user/mac.nix`,
`home/profiles/workstation.nix`.

`workstation.nix` is registered but unused; `input-leap` is declared per-host
instead.

Option A (revive): give it a real home.

- In `lib/hosts.nix`, add `"workstation"` to `main`/`mac`
  `homeManager.profiles = [ "desktop" "workstation" ]`.
- Move `input-leap` from `main.nix`/`mac.nix` into `workstation.nix` (keep host-only
  aliases like `input-server`/`input-main` where the hostname/FQDN differs).

Option B (delete): remove `home/profiles/workstation.nix`, its entry in
`flake/hosts.nix:24-26` (`homeManagerProfileModules.workstation`), and
`"workstation"` from `knownHomeManagerProfiles` in `lib/hosts.nix:46-49`. Keep
`input-leap` where it is.

Prefer Option A only if you actually want a shared dev-input profile; otherwise B is
less surface. Either way the comment at `lib/hosts.nix:226` should stop referencing
a "workstation dev-tool block" that doesn't exist.

Validate:

```bash
bash scripts/validate.sh flake-eval     # lib/hosts.nix invariants run here
bash scripts/validate.sh light
bash scripts/validate.sh host main
deadnix .                                # confirms no dead file left dangling
```

---

## FIX 5 (P0.6) — Set a real GTK theme

Files: `home/profiles/desktop.nix` (gtk block, line ~82), and move
`gnome-themes-extra` from `modules/nixos/profiles/desktop.nix:63` to HM (or keep
system-level and just reference it).

Current HM gtk block only sets dark-prefer hints. Fix:

```nix
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
  };
```

Note `home/users/user/home.nix:321` sets `gtk.gtk4.theme = null` — leave gtk4 to
libadwaita (which ignores GTK themes), but gtk3 apps (thunar, blueman, pavucontrol)
will now go properly dark. For full theme-system integration see FIX 7.

Validate:

```bash
bash scripts/validate.sh flake-eval
bash scripts/validate.sh host main
```

---

## FIX 6 (P0.2) — Drive the kitty/terminal ANSI 16 palette from the theme

File: `home/theme/module.nix:111-128`.

`color1..color6` / `color9..color14` are hardcoded gruvbox for every theme. Either:

(a) Add a full 16-color block to each `home/theme/themes/*.nix`:

```nix
  colors = { bg = ...; brown = ...; orange = ...; amber = ...; text = ...;
    ansi = {
      red = "..."; green = "..."; yellow = "..."; blue = "...";
      magenta = "..."; cyan = "...";
      brightRed = "..."; ... };
  };
```

and reference `theme.colors.ansi.*` in `mkThemeConfig`; or

(b) derive a reasonable ramp from the existing 5 colors in Nix (less ideal — hand
tuned per theme looks better). Prefer (a).

This makes `bat`'s `base16` theme (`base.nix:96`), lazygit, btop, and `:terminal`
actually reflect the active theme.

Validate:

```bash
bash scripts/validate.sh flake-eval     # all 8 themes must still eval (foldl over validThemes)
bash scripts/validate.sh host main
# visually: theme-switch <name>; new kitty window; run `bat`/`btop`
```

---

## FIX 7 (P0.1 / P3.1) — Bridge the theme into Neovim

Files: `home/theme/module.nix` (it exposes `themes._activeThemeColors`),
`home/neovim/module.nix` (it builds the generated config), and a small consumer in
`home/files/nvim/lua/config/ui.lua`.

Today `ui.lua:1-3` hardcodes gruvbox-material. Make neovim consume the active
palette. Minimal approach: emit a generated lua highlight file from the active
theme colors and source it instead of (or after) the colorscheme.

In `home/neovim/module.nix`, thread `config.themes._activeThemeColors` into the
generated config (it already builds `generatedConfig`/`generatedLua`). Add e.g.:

```nix
  generatedConfig = {
    # ...existing...
    theme = config.themes._activeThemeColors or {};
  };
```

Then in `ui.lua`, after loading `config.generated`, if `generated.theme` is present,
either pick `vim.o.background` from luminance and set gruvbox-material knobs, or
apply a tiny custom highlight set (Normal/NormalFloat/LineNr/Visual/Comment from
`bg`/`brown`/`text`/`amber`/`orange`). For correctness across all 8 themes, at
minimum set `vim.o.background` so light-leaning palettes don't render as dark-on-dark.

Caveat: the theme module supports runtime `theme-switch` without rebuild (it reads
`active.nix` at activation). Neovim config is in the Nix store, so a pure runtime
switch won't re-theme an already-open nvim — document that nvim picks up the new
theme on next launch, or have `theme-switch.sh` also write a small lua file under
`~/.config/nvim` that `ui.lua` reads at startup (parallel to how mako/kitty are
symlinked).

Validate:

```bash
bash scripts/validate.sh flake-eval
bash scripts/validate.sh host main
# nvim --headless "+lua print(vim.o.background)" +qa  -> matches active theme intent
```

---

## FIX 8 (P1.4) — Make the command-not-found handler portable

File: `home/profiles/base.nix:159-203`.

Hardcoded `/run/current-system/sw/bin/nix-locate` breaks on non-NixOS HM
(`homeConfigurations.user`, `user@wsl`). Fix the resolution:

```sh
local nl
nl=$(command -v nix-locate 2>/dev/null) || nl="/run/current-system/sw/bin/nix-locate"
attrs=("''${(@f)$("$nl" --minimal --no-group --type x --type s --whole-name --at-root "/bin/$cmd" 2>/dev/null)}")
```

Also guard: if `nix-locate` isn't found at all, just print "command not found" and
return 127 without the install hints.

Validate:

```bash
bash scripts/validate.sh flake-eval
nix build .#homeConfigurations.\"user@wsl\".activationPackage
```

---

## FIX 9 (P2.2) — Single source of truth for mako config

Files: `home/theme/module.nix:155-171` (per-theme mako template) is canonical.
`home/files/scripts/theme-switch.sh:152` contains a stale inline mako block — remove
the inline writing from the script and rely on the symlinked per-theme `mako-config`
(the script should just `makoctl reload` / restart mako after the symlink swap).

Validate:

```bash
bash scripts/validate.sh flake-eval
bash scripts/validate.sh host main
shellcheck home/files/scripts/theme-switch.sh   # (pre-commit runs this)
```

---

## FIX 10 (P2.4) — Drop redundant hypridle package

File: `home/users/user/home.nix:283` — remove the bare `hypridle` from
`home.packages`; `services.hypridle.enable = true` (line ~398) already brings it.

Validate:

```bash
bash scripts/validate.sh flake-eval
bash scripts/validate.sh host main
deadnix .
```

---

## FIX 11 (P3.4) — Enable nix-direnv

File: `home/users/user/home.nix:334-338`.

```nix
    direnv = {
      enable = true;
      nix-direnv.enable = true;   # add: cached, fast `use flake`
      enableZshIntegration = true;
    };
```

Validate: `bash scripts/validate.sh flake-eval && bash scripts/validate.sh host main`

---

## FIX 12 (P3.6) — Git productivity defaults

File: `home/profiles/base.nix:35-42` (`programs.git.settings`).

```nix
      settings = {
        init.defaultBranch = "main";
        pull.ff = "only";
        core.editor = "nvim";
        rerere.enabled = true;
        merge.conflictStyle = "zdiff3";
        diff.algorithm = "histogram";
        # core.excludesFile to a global gitignore if desired
      };
```

And add `glr = "git pull --rebase";` to `home/users/user/common.nix` aliases (P1.3).

Validate: `bash scripts/validate.sh flake-eval`

---

## FIX 13 (P3.7) — WSL clipboard provider

File: `home/users/user/common.nix` (or a wsl-specific block in `wsl.nix`).
`options.lua:13` sets `clipboard=unnamedplus`; on WSL there's no wl-copy/win32yank,
so system-clipboard yank no-ops. Add `win32yank` (or rely on Neovim's WSL clip
provider) for the wsl context only:

```nix
# in wsl.nix
home.packages = [ pkgs.win32yank ];
```

Validate: `nix build .#homeConfigurations.\"user@wsl\".activationPackage`

---

## Suggested ordering

1. FIX 1, 2, 3 (neovim correctness — texlab, clangd/c pack, toolchain) — highest
   impact, lowest risk.
2. FIX 4 (kill/realize workstation dead code).
3. FIX 6, 7, 5 (theme propagation: terminal ANSI, neovim, GTK).
4. FIX 8, 9, 10 (portability + dedup).
5. FIX 11, 12, 13 (productivity additions).

After all changes: `bash scripts/validate.sh hosts` then `pre-commit run
--all-files`.
