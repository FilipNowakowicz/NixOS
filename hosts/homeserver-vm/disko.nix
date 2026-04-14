# Disk layout for the QEMU/KVM test VM — /dev/vda (virtio block device).
# Apply with: disko --mode format hosts/homeserver-vm/disko.nix  (destructive, VM only)
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/vda";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            extraArgs = [
              "-n"
              "main-boot"
            ];
          };
        };
        root = {
          size = "12G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            extraArgs = [
              "-L"
              "main-root"
            ];
          };
        };
        persist = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/persist";
            extraArgs = [
              "-L"
              "persist"
            ];
          };
        };
      };
    };
  };
}
