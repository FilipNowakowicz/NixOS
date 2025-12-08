{ config, pkgs, lib, username ? "nixos", ... }:
let
  normalUsers = builtins.filter
    (name: (config.users.users.${name}.isNormalUser or false))
    (builtins.attrNames config.users.users);

  primaryUser = lib.findFirst (_: true) username normalUsers;
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

  users.users = lib.mkIf (config.users.users ? ${primaryUser}) {
    ${primaryUser}.extraGroups = lib.mkAfter [ "libvirtd" ];
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
