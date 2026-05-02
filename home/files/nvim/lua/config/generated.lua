return vim.json.decode([[
{
  "languages": {
    "nix": {
      "enable": true
    },
    "python": {
      "enable": true,
      "test_runner": "pytest",
      "dap": true
    },
    "tex": {
      "enable": true,
      "grammar": true
    }
  },
  "lsp": {
    "enable": [
      "nixd",
      "basedpyright"
    ],
    "settings": {
      "basedpyright": {
        "basedpyright": {
          "analysis": {
            "typeCheckingMode": "basic",
            "diagnosticSeverityOverrides": {
              "reportUnknownParameterType": "none",
              "reportUnknownArgumentType": "none",
              "reportUnknownVariableType": "none",
              "reportUnknownMemberType": "none",
              "reportMissingTypeStubs": "none"
            }
          }
        }
      }
    }
  },
  "formatters_by_ft": {
    "lua": [
      "stylua"
    ],
    "nix": [
      "nixfmt"
    ],
    "python": [
      "ruff_format"
    ]
  },
  "linters_by_ft": {
    "python": [
      "ruff"
    ]
  },
  "tests": {
    "adapters": [
      {
        "plugin": "neotest-python",
        "filetypes": [
          "python"
        ],
        "config": {
          "dap": {
            "justMyCode": false
          },
          "runner": "pytest"
        }
      }
    ]
  },
  "dap": {
    "configurations": {
      "python": [
        {
          "type": "python",
          "request": "launch",
          "name": "Launch file",
          "program": "${file}",
          "useSystemPython": true
        }
      ]
    }
  },
  "project_detection": {
    "enable": true,
    "markers": {
      "nix": [
        "flake.nix",
        "shell.nix",
        "default.nix"
      ],
      "python": [
        "pyproject.toml",
        "pytest.ini",
        ".python-version",
        "requirements.txt"
      ],
      "tex": [
        ".latexmkrc",
        "latexmkrc"
      ]
    }
  }
}
]])
