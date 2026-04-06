# Disk layout for the home server — /dev/sda (verify with lsblk on target hardware).
# Apply with nixos-anywhere or: disko --mode format hosts/homeserver/disko.nix
{
  disko.devices.disk.main = {
    type   = "disk";
    device = "/dev/sda";
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
          size    = "12G";
          content = {
            type       = "filesystem";
            format     = "ext4";
            mountpoint = "/";
            extraArgs  = [ "-L" "main-root" ];
          };
        };
        persist = {
          size    = "100%";
          content = {
            type       = "filesystem";
            format     = "ext4";
            mountpoint = "/persist";
            extraArgs  = [ "-L" "persist" ];
          };
        };
      };
    };
  };
}
