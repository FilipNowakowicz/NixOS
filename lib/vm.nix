# VM registry — single source of truth for all QEMU/KVM virtual machines.
# Everything else (QEMU launch, SSH config, deploy-rs nodes, disk paths)
# is derived from this file.
#
# To add a new VM:
#   1. Add an entry here
#   2. Create hosts/<name>/default.nix (import ../../modules/nixos/profiles/vm.nix)
#   3. Generate sops secrets: nix run '.#vm' -- init <name>
#   4. nix run '.#vm' -- create <name>
{
  vm = {
    sshPort = 2222;
    diskSize = "40G";
  };
  homeserver-vm = {
    sshPort = 2223;
    diskSize = "20G";
  };
}
