{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/virtualisation/google-compute-image.nix"
  ];

  # Target a 50 GB boot disk; OpenTofu disk_size_gb variable must match.
  virtualisation.diskSize = 51200;
}
