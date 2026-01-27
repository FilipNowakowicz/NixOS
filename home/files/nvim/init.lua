-- Entry point: just wire modules together.

require("config.options")
require("config.plugins")  -- lazy.nvim + plugin list
require("config.lsp")      -- mason, LSP, cmp, diagnostics
require("config.ui")       -- treesitter, telescope, nvim-tree, lualine, gitsigns
require("config.tex")      -- vimtex + TeX QoL
require("config.keymaps")  -- global non-LSP keymaps
require("config.dap")      -- Debug Adapter Protocol
require("config.tests")    -- testing framework integration
