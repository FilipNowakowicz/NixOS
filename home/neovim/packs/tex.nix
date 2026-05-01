{
  lib,
  pkgs,
  cfg,
}:
{
  packages = [ pkgs.texlab ] ++ lib.optional cfg.languages.tex.grammar pkgs.ltex-ls-plus;

  lsp = {
    enable = [ ];
    settings = { };
  };

  formatters = { };

  linters = { };

  tests.adapters = [ ];

  dap = { };

  projectMarkers = {
    tex = [
      ".latexmkrc"
      "latexmkrc"
    ];
  };
}
