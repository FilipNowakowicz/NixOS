{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/installer/scan/not-detected.nix"
  ];

  boot.initrd.availableKernelModules = [ "ata_piix" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/lab-root";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/lab-boot";
    fsType = "ext4";
  };

  swapDevices = [{ device = "/dev/disk/by-label/lab-swap"; }];
}
