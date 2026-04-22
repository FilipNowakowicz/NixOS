{ inputs, lib, ... }:
{
  imports = [
    inputs.microvm.nixosModules.microvm
    inputs.impermanence.nixosModules.impermanence
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

  # /persist is mounted by microvm.volumes; mark it needed for boot so
  # impermanence can bind-mount from it during early activation.
  fileSystems."/persist".neededForBoot = true;

  # ── Impermanence base (hosts extend with service-specific dirs) ────────────
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
  };

  # ── Sops (key file injected via virtiofs by the host) ─────────────────────
  # Hosts set defaultSopsFile and declare secrets; this disables SSH-key
  # derivation in favour of the virtiofs-shared age key.
  sops = {
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = lib.mkForce [ ];
  };

  # ── Networking base (static; hosts configure addresses) ───────────────────
  networking = {
    useDHCP = false;
    useNetworkd = true;
  };
  networking.networkmanager.enable = lib.mkForce false;

  # ── Sudo (passwordless — acceptable for local VMs) ────────────────────────
  security.sudo.wheelNeedsPassword = false;

  # ── SSH ────────────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  # ── Nix ────────────────────────────────────────────────────────────────────
  nix.settings.trusted-users = [
    "root"
    "user"
  ];
}
