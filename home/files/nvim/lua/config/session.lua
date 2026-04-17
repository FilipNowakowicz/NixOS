local ok, persistence = pcall(require, "persistence")
if not ok then
  return
end

persistence.setup()

local map = vim.keymap.set
map("n", "<leader>qs", function() persistence.load() end, { desc = "Restore session" })
map("n", "<leader>ql", function() persistence.load({ last = true }) end, { desc = "Last session" })
map("n", "<leader>qd", function() persistence.stop() end, { desc = "Don't save session" })
