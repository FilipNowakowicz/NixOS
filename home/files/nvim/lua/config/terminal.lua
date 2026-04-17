local ok, toggleterm = pcall(require, "toggleterm")
if not ok then
  return
end

toggleterm.setup({
  direction = "horizontal",
  size = 15,
  open_mapping = [[<C-\>]],
  shade_terminals = true,
})

-- Lazygit float
local Terminal = require("toggleterm.terminal").Terminal
local lazygit = Terminal:new({
  cmd = "lazygit",
  direction = "float",
  hidden = true,
  float_opts = { border = "rounded" },
})

vim.keymap.set("n", "<leader>gg", function()
  lazygit:toggle()
end, { desc = "Lazygit" })
