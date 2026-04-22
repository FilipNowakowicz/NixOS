I made some changes to my config I want you to walk through it verify that all the comments and general structure is correct, then verify that the claude.md and readme files are correct and update them with the new additions. Note that some of the features might already be included in readme or claude but still go through them and make sure they match the style and context etc. Also check if the folder and file structure is optimal since a few new files were added. Some of these changes might have been more than descibed below. The main changes that were made are:

- USBGuard (quick); AppArmor profiles for exposed services (medium); fail2ban (quick, homeserver when it lands).
- Systemd hardening DSL (medium) — extract from lib/sandbox.nix into a proper module (services.hardened.<name> with ProtectSystem=strict, NoNewPrivileges, RestrictNamespaces, SystemCallFilter=@system-service, etc.). Apply to every service you ship. Becomes your first candidate for extraction as a shareable module (goal #2 in GOALS.md).
- microvm.nix (medium) — run multiple lightweight NixOS VMs from main without QEMU orchestration. Replaces much of scripts/vm.sh for fast-iteration workflows and enables the purple-team target above. (scriptts/vm.sh marked as deprecated could be used for futureif testing disk arrangements)

* - homeserver-vm now runs as microvm@homeserver-vm.service on main via cloud-hypervisor

- Boots in ~7s, virtiofs store sharing (no slow erofs build)
- Age key injected via virtiofs share — solves the first-boot secrets bootstrap
- Bridge networking (microvm-br0, 10.0.100.0/24) with NAT via WiFi
- Vaultwarden + Syncthing + full observability stack confirmed running
- scripts/vm.sh archived, CLAUDE.md updated
- All checks pass: invariants, flake check, smoke tests
