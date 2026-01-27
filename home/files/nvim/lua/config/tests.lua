local ok_neotest, neotest = pcall(require, "neotest")
if not ok_neotest then
  return
end

neotest.setup({
  adapters = {
    require("neotest-python")({
      dap = { justMyCode = false },
      runner = "pytest",
    }),
  },
})

local map = vim.keymap.set

map("n", "<leader>tt", function()
  neotest.run.run()
end, { silent = true, desc = "Test nearest" })

map("n", "<leader>tT", function()
  neotest.run.run(vim.fn.expand("%"))
end, { silent = true, desc = "Test file" })

map("n", "<leader>tl", function()
  neotest.run.run_last()
end, { silent = true, desc = "Test last" })

map("n", "<leader>ts", function()
  neotest.summary.toggle()
end, { silent = true, desc = "Test summary" })

map("n", "<leader>to", function()
  neotest.output_panel.toggle()
end, { silent = true, desc = "Test output" })

map("n", "<leader>tn", function()
  neotest.jump.next()
end, { silent = true, desc = "Next test" })

map("n", "<leader>tp", function()
  neotest.jump.prev()
end, { silent = true, desc = "Prev test" })
