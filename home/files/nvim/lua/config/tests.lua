-- Test runner: neotest + neotest-python

local ok_neotest, neotest = pcall(require, "neotest")
if not ok_neotest then
  return {}
end

neotest.setup({
  adapters = {
    require("neotest-python")({
      dap = { justMyCode = false },
      runner = "pytest", -- change to "unittest" if you prefer
    }),
  },
})

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Core test mappings
map("n", "<leader>tt", function() neotest.run.run() end, vim.tbl_extend("force", opts, { desc = "Test nearest" }))
map("n", "<leader>tT", function() neotest.run.run(vim.fn.expand("%")) end,
  vim.tbl_extend("force", opts, { desc = "Test file" }))
map("n", "<leader>tl", function() neotest.run.run_last() end,
  vim.tbl_extend("force", opts, { desc = "Test last" }))

map("n", "<leader>ts", function() neotest.summary.toggle() end,
  vim.tbl_extend("force", opts, { desc = "Test summary" }))
map("n", "<leader>to", function() neotest.output_panel.toggle() end,
  vim.tbl_extend("force", opts, { desc = "Test output" }))
map("n", "<leader>tn", function() neotest.jump.next() end,
  vim.tbl_extend("force", opts, { desc = "Next test" }))
map("n", "<leader>tp", function() neotest.jump.prev() end,
  vim.tbl_extend("force", opts, { desc = "Prev test" }))

return {}
