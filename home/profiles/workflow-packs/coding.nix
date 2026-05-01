{
  lib,
  config,
  pkgs,
  skipHeavyPackages ? false,
  ...
}:
let
  cfg = config.workflowPacks.coding;
in
{
  config = lib.mkIf (cfg.enable && !skipHeavyPackages) {
    home.packages = with pkgs; [ vscode ];
  };
}
