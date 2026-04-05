{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/installer/scan/not-detected.nix"
  ];

  # Virtio guest kernel modules
  boot.initrd.availableKernelModules = [
    "virtio_pci" "virtio_blk" "virtio_scsi"
    "xhci_pci" "sd_mod"
  ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/main-root";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/main-boot";
    fsType = "vfat";
  };

  swapDevices = [{ device = "/dev/disk/by-label/main-swap"; }];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
