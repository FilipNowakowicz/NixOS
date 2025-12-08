{ config, pkgs, lib, username ? "nixos", ... }:
let
  hasPrimaryUser = builtins.hasAttr username config.users.users;
in {
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
    };
  };

  programs.virt-manager.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  users.users = lib.mkIf hasPrimaryUser {
    ${username}.extraGroups = lib.mkAfter [ "libvirtd" ];
  };

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
