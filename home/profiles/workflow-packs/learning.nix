{
  lib,
  config,
  pkgs,
  skipHeavyPackages ? false,
  ...
}:
let
  cfg = config.workflowPacks.learning;
in
{
  config = lib.mkIf (cfg.enable && !skipHeavyPackages) {
    home.packages = with pkgs; [ anki ];
  };
}
