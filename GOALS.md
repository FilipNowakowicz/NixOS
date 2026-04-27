1. Desktop “daily driver” profile as a product
   Turn main into a more intentional workstation layer: app launcher, workspace conventions, keybinding docs, Waybar modules, screenshot/OCR workflow, clipboard history, focus modes,
   battery/performance modes, and per-context theme switching. This is user-visible and not security-heavy.

2. Declarative personal workflow packs
   Add profile modules like:

home.profiles = {
writing.enable = true;
coding.enable = true;
latex.enable = true;
media.enable = true;
};

Each pack could install tools, editor config, shell aliases, desktop entries, file associations, and validation checks. This is a cleaner way to grow your workstation without dumping
everything into workstation.nix.

3. Repo-native ops CLI
   Create nix run .#ops -- <command> for local workflows:

nix run .#ops -- check main
nix run .#ops -- diff-closure main
nix run .#ops -- switch main
nix run .#ops -- theme list
nix run .#ops -- doctor

This would replace remembering many scripts and commands with one stable interface.

4. Desktop rollback/snapshot workflow
   Add a proper “safe upgrade” flow for main: build, show closure diff, switch, record generation metadata, and provide a friendly rollback command. This is different from security patching
   because it changes how you operate the workstation.

5. Theme studio
   You already have runtime themes. Expand that into a proper theme system: preview command, random/scheduled themes, wallpaper generation/import conventions, automatic contrast checks, and
   generated Kitty/Waybar/Hyprland/Mako colors from one schema.

6. NixOS config dashboard
   Generate a local static HTML or terminal report from your flake: hosts, enabled profiles, packages, closure sizes, state versions, open TODOs, validation commands, and profile membership.
   This gives you “system inventory” without needing to inspect Nix files manually.

7. Developer environment templates
   Add reusable dev shells/templates for common project types:

nix flake init -t ~/nix#rust
nix flake init -t ~/nix#python
nix flake init -t ~/nix#node

This turns your Nix repo into a personal development platform, not just machine config.

8. Better Neovim as a first-class module
   Your Neovim config is already checked in. You could make it more declarative: language packs, test runners, DAP profiles, project-local detection, and a generated cheatsheet. This is
   likely high daily value if you live in the editor.
