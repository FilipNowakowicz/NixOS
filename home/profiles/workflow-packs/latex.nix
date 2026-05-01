{
  lib,
  config,
  pkgs,
  skipHeavyPackages ? false,
  ...
}:
let
  cfg = config.workflowPacks.latex;
in
{
  config = lib.mkIf (cfg.enable && !skipHeavyPackages) {
    home.packages = with pkgs; [
      zathura
      texlive.combined.scheme-medium
      texlab
      ltex-ls-plus
    ];
  };
}
