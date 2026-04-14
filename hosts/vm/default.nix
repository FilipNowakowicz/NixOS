{ config, ... }:
{
  imports = [
    ../../modules/nixos/profiles/vm.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/desktop.nix
    ../../modules/nixos/profiles/security.nix
    ../../modules/nixos/profiles/user.nix
    ../../modules/nixos/profiles/server.nix
  ];

  system.stateVersion = "24.11";
  networking.hostName = "vm";

  # ── Impermanence (extends vm.nix base) ─────────────────────────────────────
  environment.persistence."/persist".directories = [
    "/etc/NetworkManager/system-connections"
  ];

  # ── User ────────────────────────────────────────────────────────────────────
  users.users.user = {
    home = "/home/user";
    extraGroups = [ "video" ];
    hashedPasswordFile = config.sops.secrets.user_password.path;
    openssh.authorizedKeys.keys = import ../../lib/pubkeys.nix;
  };

  # ── Sops ────────────────────────────────────────────────────────────────────
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    secrets.example_secret = { };
    secrets.user_password.neededForUsers = true;
  };

  # ── Home Manager ────────────────────────────────────────────────────────────
  home-manager.users.user.imports = [ ../../home/users/user/home.nix ];
}
