{ pkgs, generatedConfig }:

pkgs.writeText "nvim-generated.lua" ''
  return vim.json.decode([[
  ${builtins.toJSON generatedConfig}
  ]])
''
