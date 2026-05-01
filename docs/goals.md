# Project Roadmap & Goals

This document tracks the evolution of this NixOS configuration, from immediate next steps to longer-term directions.

---

## Active

### Goal 01 — Desktop "daily driver" profile

Turn `main` into a more intentional workstation layer. Tackled incrementally — each item is independent and shippable on its own.

#### Ready to implement

- [x] **Volume/brightness OSD** — `swayosd` shows a floating Windows-style popup when media keys fire. Hooks into existing `brightnessctl`/`wpctl` binds in `hyprland.conf`, no design work needed.
- [ ] **Performance modes** — `power-profiles-daemon` exposes balanced/performance/power-saver. Battery icon in Waybar gets a click action to cycle modes and an icon reflecting the active mode.
- [ ] **Wallpaper transitions** — swap `swaybg` for `swww` so theme switches and wallpaper changes animate with a crossfade instead of a hard cut.
- [ ] **Bluetooth menu** — replace Blueman (half-screen app) with a `bluetoothctl`-driven `fuzzel` popup: lists paired devices, click to connect/disconnect.
- [ ] **WiFi menu** — replace `networkmanagerapplet` tray with an `nmcli`-driven `fuzzel` popup launched from the Waybar network module.
- [ ] **Volume menu** — Waybar audio module opens a thin custom popup for output/input switching (via `wpctl` or `pavucontrol`), separate from the OSD.

#### Needs design discussion

- [ ] **App launcher** — existing launchers (wofi, rofi, fuzzel) all available; design direction TBD.
- [ ] **Spotify/MPRIS controls in Waybar** — show current track, pause/skip via `playerctl`. Must filter to music players only (exclude browsers, video). Design and allowlist TBD.
- [ ] **Clipboard history GUI** — `cliphist` + `fzf` already works; upgrade to a `fuzzel`-based picker for consistency with other menus.

#### Deferred (low urgency or blocked on discussion)

- [ ] **Scratchpad terminal** — dropdown Kitty via `Super+backtick` using Hyprland's native scratchpad. High daily value, low effort.
- [ ] **Night mode** — `hyprsunset` for blue-light reduction. Waybar toggle or auto-schedule by time of day.
- [ ] **Idle inhibitor toggle** — Waybar button that pauses `hypridle` (e.g. when watching something outside a browser).
- [ ] **Do-not-disturb toggle** — `makoctl mode +dnd` wired to a Waybar button; silences notifications on demand.
- [ ] **Emoji picker** — `fuzzel`-based, one keybind, types emoji into focused window.
- [ ] **Color picker** — `hyprpicker` to grab hex colors off screen; useful for dev/design.
- [ ] **GTK/cursor/icon theming** — wire `gtk.theme`, `cursorTheme`, and an icon pack (e.g. Papirus) through home-manager so all apps match the active theme. Discuss alongside theme studio.
- [ ] **Screenshot workflow** — `satty` for annotation after `grim` capture; `tesseract` OCR pipeline outputting to clipboard.
- [ ] **Keybinding cheat sheet** — auto-generated popup from `hyprland.conf` binds, shown via `Super+?`.

---

## Homeserver

The homeserver modules are already hardware-agnostic. Two paths forward — GCP unblocks the deferred pile without waiting on physical hardware.

### Path A — GCP (cloud homeserver, unblocks deferred items)

- [ ] **GCP homeserver** (medium–substantial) — build a GCE image from the existing homeserver config (`nixos-generators -f gce`), push to GCS, boot via Terraform/OpenTofu. Join tailnet as a subnet router. Unlocks everything below.

### Path B — Real hardware (blocked)

- [ ] **Homeserver on real hardware** — generate hardware config, provision Tailscale auth key, add host age key to `.sops.yaml`, deploy, create first Vaultwarden account. Full checklist in `hosts/homeserver/CLAUDE.md`.

### Deferred (either path unlocks these)

- [ ] **Automated deploy pipeline** — add a self-hosted GitHub Actions runner as a NixOS service on the homeserver (always-on, has KVM). Extend smoke test to probe live endpoints (Grafana login, ingest auth). Add automated deploy job that deploys homeserver then main in order after smoke test passes. CI already builds all closures and caches them via magic-nix-cache. Secrets rotation (ingest credentials, Grafana admin password) becomes a cheap add-on once deploy is automated — Tailscale auth key stays manual.
- [ ] **Off-site backup (B2)** — replace local-only restic repository on homeserver with Backblaze B2. Add sops secret for B2 credentials (`B2_ACCOUNT_ID` + `B2_ACCOUNT_KEY`), update repository URL. Local backup on `main` can follow the same pattern later.
- [ ] **Local DNS & ad-blocking** — deploy AdGuard Home on the homeserver (or GCE VM), integrated with Tailscale MagicDNS for network-wide privacy.
- [ ] **LGTM tuning** — expand dashboards and alerts, tune retention/cardinality for long-running operation. Add alerting rules for disk usage >80%, service restarts, and backup failures.
- [ ] **Host introspection → LGTM** (medium) — auditd + osquery or lynis timer → logs to Loki → dashboards. Pairs with the existing observability stack; proves the LGTM investment for something beyond infra metrics.
- [ ] **Service composition DSL** (medium–substantial) — a module like `services.app.<name> = { package, port, backup, observe, harden }` that auto-wires sandboxing, systemd hardening, log shipping, and restic targets. Eliminates the "add a service → remember to also wire 5 cross-cutting things" tax.
- [ ] **Expand typed generator approach to additional domains (for example nginx vhosts/timers).**
- [ ] **Create secret rotation ritual/checklist + age/rotation observability metric.**
