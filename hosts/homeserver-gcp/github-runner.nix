{
  config,
  pkgs,
  ...
}:
{
  services.github-runners.homeserver-deploy = {
    enable = true;
    name = "homeserver-gcp-deploy";
    url = "https://github.com/FilipNowakowicz/nixos-config";
    tokenFile = config.sops.secrets.github_runner_homeserver_deploy_token.path;
    replace = true;

    # The deploy workflow is manual and main-branch gated. Run it as the same
    # account deploy-rs already uses so SSH and activation follow the existing
    # homeserver deployment path.
    user = "user";
    extraEnvironment.HOME = "/home/user";

    extraLabels = [
      "nixos"
      "homeserver-gcp"
      "homeserver-deploy"
    ];

    extraPackages = with pkgs; [
      openssh
      rsync
    ];

    serviceOverrides = {
      ProtectHome = false;
    };
  };

  systemd.services.github-runner-homeserver-deploy = {
    wants = [ "sops-install-secrets.service" ];
    after = [ "sops-install-secrets.service" ];
  };
}
