vim.g.gruvbox_material_background = "medium"
vim.g.gruvbox_material_foreground = "material"
pcall(vim.cmd.colorscheme, "gruvbox-material")

-----------------------------------------------------------
-- Oil (file explorer)
-----------------------------------------------------------
pcall(function()
  require("oil").setup({
    default_file_explorer = true,
    view_options = { show_hidden = false },
  })
end)

-----------------------------------------------------------
-- Autopairs
-----------------------------------------------------------
pcall(function()
  require("nvim-autopairs").setup()
end)

-----------------------------------------------------------
-- Treesitter
-----------------------------------------------------------
pcall(function()
  require("nvim-treesitter.configs").setup({
    ensure_installed = { "c", "python", "lua", "nix", "latex", "bibtex" },
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
  require("treesitter-context").setup({ max_lines = 3 })
end)

-----------------------------------------------------------
-- Telescope
-----------------------------------------------------------
pcall(function()
  require("telescope").setup({
    defaults = {
      sorting_strategy = "ascending",
      layout_config = { prompt_position = "top" },
    },
  })
  pcall(require("telescope").load_extension, "fzf")
end)

-----------------------------------------------------------
-- Git / motion / statusline
-----------------------------------------------------------
pcall(function() require("gitsigns").setup() end)
pcall(function() require("lualine").setup() end)

pcall(function()
  require("leap").add_default_mappings()
  vim.keymap.set({ "n", "o" }, "gs", function()
    pcall(function() require("leap.remote").action() end)
  end, { desc = "Leap remote" })
end)

-----------------------------------------------------------
-- Trouble
-----------------------------------------------------------
pcall(function()
  require("trouble").setup()

  local map = vim.keymap.set
  map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",              { desc = "Diagnostics" })
  map("n", "<leader>xf", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Buffer diagnostics" })
  map("n", "<leader>xl", "<cmd>Trouble lsp toggle<cr>",                      { desc = "LSP references/definitions" })
  map("n", "<leader>xq", "<cmd>Trouble qflist toggle<cr>",                   { desc = "Quickfix list" })
end)

-----------------------------------------------------------
-- Snacks
-----------------------------------------------------------
-- Words navigation (requires snacks.words to be enabled in plugins.lua)
vim.keymap.set("n", "]]", function() Snacks.words.jump(1, true) end,  { desc = "Next word occurrence" })
vim.keymap.set("n", "[[", function() Snacks.words.jump(-1, true) end, { desc = "Prev word occurrence" })
vim.keymap.set("n", "<leader>un", function() Snacks.notifier.show_history() end, { desc = "Notification history" })

-----------------------------------------------------------
-- which-key groups
-----------------------------------------------------------
pcall(function()
  require("which-key").add({
    { "<leader>c", group = "Copilot" },
    { "<leader>d", group = "Debug" },
    { "<leader>f", group = "Find" },
    { "<leader>g", group = "Git" },
    { "<leader>h", group = "Hunk" },
    { "<leader>l", group = "LSP" },
    { "<leader>q", group = "Session" },
    { "<leader>t", group = "Test" },
    { "<leader>u", group = "UI" },
    { "<leader>v", group = "LaTeX" },
    { "<leader>x", group = "Trouble" },
  })
end)
