{
  lib,
  config,
  pkgs,
  skipHeavyPackages ? false,
  ...
}:
let
  cfg = config.workflowPacks.browsing;
in
{
  config = lib.mkIf (cfg.enable && !skipHeavyPackages) {
    home.packages = with pkgs; [ chromium ];
  };
}
