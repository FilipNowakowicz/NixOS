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

  # Adjust labels to match your VM's actual disk setup,
  # or replace with UUIDs from `blkid` on the VM.
  fileSystems."/" = {
    device = "/dev/disk/by-label/vm-root";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/vm-boot";
    fsType = "vfat";
  };

  swapDevices = [{ device = "/dev/disk/by-label/vm-swap"; }];

  # Standard QEMU virtio disk; use systemd-boot if VM is UEFI.
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };
}
