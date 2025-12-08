{ config, pkgs, ... }:
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

  users.users.nixos.extraGroups = [ "libvirtd" ];

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
