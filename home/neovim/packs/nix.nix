{ pkgs }:
{
  packages = with pkgs; [
    nixd
    nixfmt
  ];

  lsp = {
    enable = [ "nixd" ];
    settings = { };
  };

  formatters = {
    nix = [ "nixfmt" ];
  };

  linters = { };

  tests.adapters = [ ];

  dap = { };

  projectMarkers = {
    nix = [
      "flake.nix"
      "shell.nix"
      "default.nix"
    ];
  };
}
