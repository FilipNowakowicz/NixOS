{ pkgs, ... }:
{
  environment.systemPackages = [
    # Keep common client terminal definitions available over SSH without pulling
    # every terminfo package into the server closure.
    pkgs.alacritty.terminfo
    pkgs.foot.terminfo
    pkgs.kitty.terminfo
    pkgs.wezterm.terminfo
  ];
}
