{ lib, ... }:
{
  imports = [
    ./browsing.nix
    ./coding.nix
    ./latex.nix
    ./learning.nix
  ];

  options.workflowPacks = {
    browsing.enable = lib.mkEnableOption "browser workflow pack";
    coding.enable = lib.mkEnableOption "coding workflow pack";
    latex.enable = lib.mkEnableOption "LaTeX workflow pack";
    learning.enable = lib.mkEnableOption "learning workflow pack";
  };
}
