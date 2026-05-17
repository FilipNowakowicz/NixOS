{ lib, ... }:
{
  options.profiles.ci = lib.mkEnableOption "CI evaluation mode — disables hardware-dependent features";
}
