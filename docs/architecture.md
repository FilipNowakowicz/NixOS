# Repository Architecture

This document defines the structural hierarchy and "Rules of Engagement" for the NixOS flake. Adhering to these rules prevents "topology bugs"—such as headless hosts inheriting desktop closures—and ensures the codebase remains scalable.

---

## 1. Structural Hierarchy

The configuration is organized into four distinct layers, with dependencies only flowing **downward**.

| Layer                 | Location                  | Responsibility                                             | Side Effects?   |
| :-------------------- | :------------------------ | :--------------------------------------------------------- | :-------------- |
| **Layer 3: Hosts**    | `hosts/`                  | Final assembly. Combines hardware, identity, and profiles. | **High**        |
| **Layer 2: Profiles** | `modules/nixos/profiles/` | Bundles modules into logical features (e.g., "Desktop").   | **High**        |
| **Layer 1: Modules**  | `modules/nixos/services/` | Defines custom options and internal logic (DSL).           | **Conditional** |
| **Layer 0: Lib**      | `lib/`                    | Pure logic, registries, and schema definitions.            | **None**        |

---

## 2. Dependency Graph

```mermaid
graph TD
    Host[Layer 3: Hosts] --> Profile[Layer 2: Profiles]
    Profile --> Module[Layer 1: Modules]
    Module --> Lib[Layer 0: Lib]
    Host --> Hardware[Hardware Config]

    subgraph "Core Infrastructure"
    Module
    Lib
    end
```

---

## 3. Rules of Engagement

### Rule 1: The "Side-Effect" Gate

Files that have **immediate side-effects** (e.g., adding packages to `environment.systemPackages` or enabling heavy services) **MUST NOT** be imported globally in `modules/nixos/default.nix`.

- **Manual Opt-in:** Profiles like `desktop.nix`, `nvidia-prime.nix`, and `workstation.nix` must be imported explicitly by the host.
- **Global Infrastructure:** Only modules that provide options (`mkOption`) or universal invariants (security assertions) belong in the global `imports` list.

### Rule 2: Closure Integrity

A host's Nix store closure should only contain what is explicitly requested.

- **Headless Safety:** Headless hosts (like `homeserver`) must never inherit GUI libraries or X11/Wayland dependencies.
- **Verification:** Use `nix build '.#checks.x86_64-linux.invariants-<host>'` to verify that unauthorized profiles haven't leaked into a host.

### Rule 3: Single Source of Truth (Registry)

`lib/hosts.nix` is the **Single Source of Truth (SSoT)** for host metadata.

- Network IDs, Tailscale tags, and roles must be defined in the registry, not hardcoded in modules.
- Modules should consume this data via `config.repo.host` (or similar library helpers) to adapt their behavior.
- Generators may intentionally consume only a subset of the registry. For example, `lib/acl.nix` currently uses `tailscale.tag` only and does not infer host aliases or host-specific rules from richer metadata.

### Rule 4: Module vs. Profile

- **Modules** (`modules/nixos/services/`) define _how_ a service works and provide a DSL (e.g., `services.hardened`). They should be generic and reusable.
- **Profiles** (`modules/nixos/profiles/`) define _what_ is enabled. They set the policy for the fleet (e.g., "All desktop machines use Hyprland and PipeWire").

---

## 4. Layer Definitions

### Layer 0: Lib

Pure Nix functions. These must be "cold" (no imports of system modules). They define the schema for the rest of the flake.

### Layer 1: Modules

The building blocks. These introduce new attributes to the `services` or `programs` namespace. They should use `lib.mkIf` to ensure they do nothing unless their specific `.enable` option is set.

### Layer 2: Profiles

The "Features" of the system. A profile typically imports multiple modules and configures them to work together. Profiles are the primary unit of reuse between hosts.

### Layer 3: Hosts

The entry points. A host file should be a "thin" composition of:

1.  Hardware configuration (`hardware-configuration.nix`).
2.  Disk layout (`disko.nix`).
3.  A list of Profile imports.
4.  Host-specific secrets and identity.
