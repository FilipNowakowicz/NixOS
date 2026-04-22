I made some changes to my config I want you to walk through it verify that all the comments and general structure is correct, then verify that the claude.md and readme files are correct and update them with the new additions. Note that some of the features might already be included in readme or claude but still go through them and make sure they match the style and context etc. Also check if the folder and file structure is optimal since a few new files were added. The main changes that were made are:

- nix flake check gains a module-eval test per host (quick) — pkgs.nixosTest stubs that assert invariants ("main has no passwordless sudo", "homeserver has firewall enabled"). Fast, and it closes the intent/reality gap below.

- Smoke test matrix (quick) — extend tests/nixos/ to cover main and vm, not just homeserver-vm. (Different checks on main and homeserver cause they are hardware)
