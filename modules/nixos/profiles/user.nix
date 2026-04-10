{ pkgs, ... }:
{
  users.users.user = {
    isNormalUser = true;
    description = "Primary user";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    shell = pkgs.zsh;
  };
}
