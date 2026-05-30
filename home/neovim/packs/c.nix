{ pkgs }:
{
  packages = with pkgs; [
    clang-tools
  ];

  lsp = {
    enable = [ "clangd" ];
    settings = { };
  };

  formatters = { };

  linters = { };

  tests.adapters = [ ];

  dap = { };

  projectMarkers = {
    c = [
      "compile_commands.json"
      "compile_flags.txt"
      "CMakeLists.txt"
      "Makefile"
    ];
  };
}
