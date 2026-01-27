pcall(vim.cmd.colorscheme, "vague")

pcall(function()
  require("nvim-tree").setup()
end)

pcall(function()
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
end)

pcall(function()
  require("telescope").setup({
    defaults = {
      sorting_strategy = "ascending",
      layout_config = { prompt_position = "top" },
    },
  })
  pcall(require("telescope").load_extension, "fzf")
end)

pcall(function()
  require("gitsigns").setup()
end)

pcall(function()
  require("lualine").setup()
end)

pcall(function()
  require("leap").add_default_mappings()
  vim.keymap.set({ "n", "o" }, "gs", function()
    pcall(function()
      require("leap.remote").action()
    end)
  end, { desc = "Leap remote" })
end)
