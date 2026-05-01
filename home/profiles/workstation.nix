{
  lib,
  ...
}:
{
  imports = [ ./workflow-packs ];

  workflowPacks = {
    browsing.enable = lib.mkDefault true;
    coding.enable = lib.mkDefault true;
    latex.enable = lib.mkDefault true;
    learning.enable = lib.mkDefault true;
  };
}
