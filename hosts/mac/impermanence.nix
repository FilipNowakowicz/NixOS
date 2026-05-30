{ inputs, ... }:
{
  imports = [
    inputs.impermanence.nixosModules.impermanence
    ../../modules/nixos/profiles/impermanence-base.nix
  ];

  # /nix is its own btrfs subvolume; stage 1 must mount it before stage 2
  # init (which lives in /nix/store) can exec. /persist is already marked
  # neededForBoot in impermanence-base.nix.
  fileSystems."/nix".neededForBoot = true;
  profiles.impermanence.rollbackRoot.enable = true;

  # Ephemeral root: @root is rolled back to @root-blank on every boot. Same
  # pattern as main; old roots are moved to /old_roots/<ts> for 30 days. See
  # hosts/main/impermanence.nix for the rationale and recovery walkthrough.
  environment.persistence."/persist".directories = [
    "/var/lib/tailscale" # tailnet node identity + peers
    "/var/lib/bluetooth" # Bluetooth pairings
    "/var/lib/fail2ban" # banned-IP database (resets to empty without this)
    "/etc/NetworkManager/system-connections" # saved Wi-Fi / VPN profiles
    # systemd state that affects boot-time behavior rather than runtime:
    "/var/lib/systemd/timers"
    "/var/lib/systemd/backlight"
    "/var/lib/systemd/rfkill"
  ];

}
