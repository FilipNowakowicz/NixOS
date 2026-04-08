if [ -z "$1" ]; then
  echo "Usage: nix run '.#launch-vm-iso' -- path/to/installer.iso"
  exit 1
fi
qemu-system-x86_64 -enable-kvm -machine q35 -cpu host -smp 4 -m 8G \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=/vmstore/images/nixos-test-vars.fd \
  -drive file=/vmstore/images/nixos-test.qcow2,if=virtio \
  -cdrom "$1" \
  -boot order=d \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -daemonize -display none
