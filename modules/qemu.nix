{ pkgs, lib, username, ... }:
{
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
    };
  };

  programs.virt-manager.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  # Append libvirtd group after any base user groups (see modules/base.nix).
  users.users.${username}.extraGroups = lib.mkAfter [ "libvirtd" ];

  environment.systemPackages = with pkgs; [
    libvirt
    qemu_kvm
    swtpm
    virt-manager
    virt-viewer
    virtiofsd
    virtio-win
  ];
}
