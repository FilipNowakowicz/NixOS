-- Global, non-LSP keymaps

local map = vim.keymap.set

-- Nvim-Tree
map("n", "<leader>e", ":NvimTreeToggle<CR>", { noremap = true, silent = true })

-- Telescope
map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { noremap = true })
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>",  { noremap = true })
map("n", "<leader>fb", "<cmd>Telescope buffers<cr>",     { noremap = true })
map("n", "<leader>fh", "<cmd>Telescope help_tags<cr>",   { noremap = true })

-- Gitsigns
map("n", "]c", ":Gitsigns next_hunk<CR>",    { noremap = true })
map("n", "[c", ":Gitsigns prev_hunk<CR>",    { noremap = true })
map("n", "<leader>hs", ":Gitsigns stage_hunk<CR>",   { noremap = true })
map("n", "<leader>hr", ":Gitsigns reset_hunk<CR>",   { noremap = true })
map("n", "<leader>hp", ":Gitsigns preview_hunk<CR>", { noremap = true })
map("n", "<leader>hb", ":Gitsigns blame_line<CR>",   { noremap = true })

-- Run current file with Python
map("n", "<leader>r", ":!python %<CR>", { noremap = true, silent = true })

-- Glow (Markdown Preview)
map("n", "<leader>m", "<cmd>Glow<CR>", { noremap = true, silent = true, desc = "Markdown Preview" })

return {}

