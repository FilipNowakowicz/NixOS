{ config, ... }:
{
  # ── Graphics ────────────────────────────────────────────────────────────────
  # NVIDIA GPU with Intel iGPU PRIME offload
  #
  # Hyprland renders on the Intel iGPU by default. The NVIDIA GPU is available
  # on demand via `nvidia-offload <cmd>`.

  # Needed for both Intel (Mesa) and NVIDIA (VA-API consumers, Hyprland, etc.)
  hardware.graphics.enable = true;

  # Loads the NVIDIA kernel module and wires up the Xorg/DRM stack
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true; # required for Wayland / Hyprland
    powerManagement.enable = true; # suspend/resume reliability on laptops
    open = false; # use proprietary kernel module
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # PRIME offload — Hyprland renders on the Intel iGPU by default.
    # The NVIDIA GPU is available on demand via `nvidia-offload <cmd>`.
    #
    # Verify bus IDs before the first install:
    #   lspci | grep -E "VGA|3D"
    # Format expected by NixOS: "PCI:<bus>:<slot>:<function>" (decimal)
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; # adds `nvidia-offload` wrapper to $PATH
      };
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # ── Intel iGPU / Wayland env vars ──────────────────────────────────────────
  # Pins the session to the Intel iGPU. NVIDIA is available on-demand via nvidia-offload.
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Electron apps: use Wayland backend
    LIBVA_DRIVER_NAME = "iHD"; # VA-API → Intel Media Driver
    __GLX_VENDOR_LIBRARY_NAME = "mesa"; # GLX → Mesa (Intel) by default
    # Pins Hyprland's primary GPU to the Intel iGPU so it doesn't accidentally
    # pick the NVIDIA card.  Verify after install:
    #   ls -la /dev/dri/by-path/ | grep 'pci-0000:00:02'
    # AQ_DRM_DEVICES              = "/dev/dri/by-path/pci-0000:00:02.0-card";
    AQ_DRM_DEVICES = "/dev/dri/card1";
  };
}
