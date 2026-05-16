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

  # Phase 1: minimal persistence. @root is NOT wiped yet, so state in
  # /var/lib/* still survives reboots on its own. Expand this list
  # incrementally; each new entry requires a one-time copy from @root
  # into /persist BEFORE the rebuild that adds it:
  #
  #   sudo cp -a /var/lib/tailscale /persist/var/lib/
  #   sudo nh os switch --hostname main .
  #
  # otherwise the bind mount lands on an empty dir and the service loses
  # its state.
  #
  # Phase 2: selective state migration to /persist (one-time copy before each line is uncommented)
  environment.persistence."/persist".directories = [
    "/var/lib/sbctl" # Lanzaboote / Secure Boot PKI
    "/var/lib/tailscale" # tailnet node identity + peers
    "/var/lib/bluetooth" # Bluetooth pairings
    "/var/lib/fprint" # fingerprint enrollments
    "/var/lib/usbguard" # USBGuard rule hashes
    "/etc/NetworkManager/system-connections" # saved Wi-Fi / VPN profiles
    "/var/cache/mullvad-vpn" # Mullvad VPN cache
    # Phase 2 candidates (not yet present, uncomment when installed):
    # "/var/lib/AccountsService"                  # display-manager user metadata
    # "/var/lib/mullvad-vpn"                      # Mullvad VPN state
  ];
}
