-- UI-related plugin setups

-----------------------------------------------------------
-- Nvim-Tree
-----------------------------------------------------------
require("nvim-tree").setup()

-----------------------------------------------------------
-- Treesitter
-----------------------------------------------------------
require("nvim-treesitter.configs").setup({
  ensure_installed = { "c", "python", "lua", "latex", "bibtex" },
  highlight = { enable = true },
  indent = { enable = true },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "gnn",
      node_incremental = "grn",
      scope_incremental = "grc",
      node_decremental = "grm",
    },
  },
  textobjects = {
    select = {
      enable = true,
      lookahead = true,
      keymaps = {
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["ac"] = "@class.outer",
        ["ic"] = "@class.inner",
      },
    },
  },
})

-----------------------------------------------------------
-- Telescope
-----------------------------------------------------------
require("telescope").setup()

-----------------------------------------------------------
-- Gitsigns
-----------------------------------------------------------
require("gitsigns").setup()

-----------------------------------------------------------
-- Statusline
-----------------------------------------------------------
require("lualine").setup()

-----------------------------------------------------------
-- Telescope
-----------------------------------------------------------
require("telescope").setup({
  defaults = {
    sorting_strategy = "ascending",
    layout_config = { prompt_position = "top" },
  },
})

pcall(require("telescope").load_extension, "fzf")

-----------------------------------------------------------
-- Leap
-----------------------------------------------------------
local ok, _ = pcall(require, "leap")
if ok then
  -- Main jump motion
  vim.keymap.set({ "n", "x", "o" }, "s", "<Plug>(leap)", {
    desc = "Leap",
  })

  -- Remote / cross-window action
  vim.keymap.set({ "n", "o" }, "gs", function()
    require("leap.remote").action()
  end, {
    desc = "Leap remote",
  })
end

return {}
