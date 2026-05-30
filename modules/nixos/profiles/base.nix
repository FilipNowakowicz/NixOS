{
  config,
  inputs,
  lib,
  pkgs,
  self,
  ...
}:
let
  configurationRevision = self.dirtyShortRev or self.shortRev or self.dirtyRev or self.rev or null;
  inherit (config.lib.profiles.observability) mkPromScript;
in
{
  zramSwap.enable = true;

  system.configurationRevision = lib.mkDefault configurationRevision;

  system.activationScripts.exportSystemMetadata.text = "${mkPromScript {
    name = "system_metadata.prom";
    lines = [
      "nixos_system_activated_at_seconds $(${pkgs.coreutils}/bin/date +%s)"
    ]
    ++ lib.optionals (configurationRevision != null) [
      ''nixos_system_revision_info{revision="${configurationRevision}"} 1''
    ];
  }}";

  # None of the current hosts use ZFS for root import. Set the upcoming 26.11
  # default explicitly across the fleet to avoid evaluation-time warnings.
  boot.zfs.forceImportRoot = lib.mkDefault false;

  # ── Nix ────────────────────────────────────────────────────────────────────
  nixpkgs.config.allowUnfree = true;
  nix = {
    registry.nixpkgs.flake = inputs.nixpkgs;

    # Keep legacy nixpkgs lookups aligned with the flake-pinned registry entry.
    nixPath = [ "nixpkgs=flake:nixpkgs" ];

    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };

    # Hardlink duplicate store paths once a week instead of after every build.
    # auto-optimise-store taxes every nix build with a synchronous dedup pass;
    # the timer-driven variant runs out-of-band and matches the gc cadence.
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  systemd.services.nix-daemon.serviceConfig = {
    # Nix builds can legitimately use all available CPU. Keep them responsive
    # enough for manual work, but bias scheduling away from interactive desktop
    # processes so transient evaluations/builds do not dominate thermals.
    CPUWeight = 50;
    Nice = 10;
    IOWeight = 50;
    IOSchedulingClass = "best-effort";
    IOSchedulingPriority = lib.mkForce 6;
  };

  # ── Localization ───────────────────────────────────────────────────────────
  time.timeZone = lib.mkDefault "Europe/Warsaw";
  i18n.defaultLocale = lib.mkDefault "en_GB.UTF-8";
  console.keyMap = lib.mkDefault "dvorak";

  # ── Shell ───────────────────────────────────────────────────────────────────
  programs.zsh.enable = lib.mkDefault true;
  users.defaultUserShell = pkgs.zsh;

  # ── System Packages ────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    curl
    pciutils
    rsync
    usbutils
    wget
  ];
}
