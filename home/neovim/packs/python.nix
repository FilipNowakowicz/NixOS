{ pkgs, cfg }:
{
  packages = with pkgs; [
    basedpyright
    ruff
  ];

  lsp = {
    enable = [ "basedpyright" ];
    settings = {
      basedpyright = {
        basedpyright = {
          analysis = {
            typeCheckingMode = "basic";
            diagnosticSeverityOverrides = {
              reportUnknownParameterType = "none";
              reportUnknownArgumentType = "none";
              reportUnknownVariableType = "none";
              reportUnknownMemberType = "none";
              reportMissingTypeStubs = "none";
            };
          };
        };
      };
    };
  };

  formatters = {
    python = [ "ruff_format" ];
  };

  linters = {
    python = [ "ruff" ];
  };

  tests.adapters = [
    {
      plugin = "neotest-python";
      filetypes = [ "python" ];
      config = {
        dap.justMyCode = false;
        runner = cfg.languages.python.testRunner;
      };
    }
  ];

  dap =
    if cfg.languages.python.dap then
      {
        python = [
          {
            type = "python";
            request = "launch";
            name = "Launch file";
            program = "\${file}";
            useSystemPython = true;
          }
        ];
      }
    else
      { };

  projectMarkers = {
    python = [
      "pyproject.toml"
      "pytest.ini"
      ".python-version"
      "requirements.txt"
    ];
  };
}
