{ inputs, lib, ... }:
{
  imports = [
    inputs.microvm.nixosModules.microvm
    inputs.impermanence.nixosModules.impermanence
    ./impermanence-base.nix
    ./machine-common.nix
  ];

  # ── Boot ──────────────────────────────────────────────────────────────────
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_net"
  ];

  # ── Root filesystem (tmpfs — wiped on each boot) ───────────────────────────
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [
      "size=2G"
      "mode=0755"
    ];
  };

  # ── Sops (key file injected via virtiofs by the host) ─────────────────────
  # Hosts set defaultSopsFile and declare secrets; this disables SSH-key
  # derivation in favour of the virtiofs-shared age key.
  sops = {
    age.sshKeyPaths = lib.mkForce [ ];
    # age.keyFile is set per-host pointing to the virtiofs-injected key
  };

  # ── Networking base (static; hosts configure addresses) ───────────────────
  networking = {
    useDHCP = false;
    useNetworkd = true;
  };
  networking.networkmanager.enable = lib.mkForce false;

}
