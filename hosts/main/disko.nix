# Placeholder disk layout for the main machine — /dev/nvme0n1.
# Before running disko-install, shrink the NixOS root partition manually
# in a live environment to leave unallocated space for a dual-boot OS.
# Then adjust the root partition size below to match.
{
  disko.devices.disk.main = {
    type   = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size    = "512M";
          type    = "EF00";
          content = {
            type       = "filesystem";
            format     = "vfat";
            mountpoint = "/boot";
            extraArgs  = [ "-n" "main-boot" ];
          };
        };
        root = {
          # Adjust size to leave room for a dual-boot OS when the time comes.
          # Use "100%" to claim all remaining space on a NixOS-only install.
          size    = "100%";
          content = {
            type       = "filesystem";
            format     = "ext4";
            mountpoint = "/";
            extraArgs  = [ "-L" "main-root" ];
          };
        };
      };
    };
  };
}
