local map = vim.keymap.set

-- Nvim-Tree
map("n", "<leader>e", function()
  vim.cmd.NvimTreeToggle()
end, { silent = true, desc = "File explorer" })

-- Telescope
map("n", "<leader>ff", function()
  require("telescope.builtin").find_files()
end, { desc = "Find files" })

map("n", "<leader>fg", function()
  require("telescope.builtin").live_grep()
end, { desc = "Live grep" })

map("n", "<leader>fb", function()
  require("telescope.builtin").buffers()
end, { desc = "Buffers" })

map("n", "<leader>fh", function()
  require("telescope.builtin").help_tags()
end, { desc = "Help tags" })

-- Gitsigns
map("n", "]c", function()
  require("gitsigns").next_hunk()
end, { desc = "Next hunk" })

map("n", "[c", function()
  require("gitsigns").prev_hunk()
end, { desc = "Previous hunk" })

map("n", "<leader>hs", function()
  require("gitsigns").stage_hunk()
end, { desc = "Stage hunk" })

map("n", "<leader>hr", function()
  require("gitsigns").reset_hunk()
end, { desc = "Reset hunk" })

map("n", "<leader>hp", function()
  require("gitsigns").preview_hunk()
end, { desc = "Preview hunk" })

map("n", "<leader>hb", function()
  require("gitsigns").blame_line()
end, { desc = "Blame line" })

-- Run current file with Python (convenience)
map("n", "<leader>r", function()
  vim.cmd("!python %")
end, { silent = true, desc = "Run current file (python)" })

-- Markdown preview
map("n", "<leader>m", "<cmd>Glow<CR>", { silent = true, desc = "Markdown preview" })
