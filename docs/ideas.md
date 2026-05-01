4. Desktop rollback/snapshot workflow
   Add a proper “safe upgrade” flow for main: build, show closure diff, switch, record generation metadata, and provide a friendly rollback command. This is different from security patching
   because it changes how you operate the workstation.


5. NixOS config dashboard
   Generate a local static HTML or terminal report from your flake: hosts, enabled profiles, packages, closure sizes, state versions, open TODOs, validation commands, and profile membership.
   This gives you “system inventory” without needing to inspect Nix files manually.

6. Better Neovim as a first-class module
   Your Neovim config is already checked in. You could make it more declarative: language packs, test runners, DAP profiles, project-local detection, and a generated cheatsheet. This is
   likely high daily value if you live in the editor.
