{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/installer/scan/not-detected.nix"
  ];

  # Virtio guest kernel modules
  boot = {
    initrd.availableKernelModules = [
      "virtio_pci" "virtio_blk" "virtio_scsi"
      "xhci_pci" "sd_mod"
    ];
    kernelModules = [ ];
    extraModulePackages = [ ];

    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };
}
