local ok_neotest, neotest = pcall(require, "neotest")
if not ok_neotest then
	return
end

local generated = require("config.generated")
local adapters = {}

for _, adapter in ipairs((generated.tests and generated.tests.adapters) or {}) do
	if adapter.plugin == "neotest-python" then
		local ok_python, neotest_python = pcall(require, "neotest-python")
		if ok_python then
			table.insert(adapters, neotest_python(adapter.config or {}))
		end
	end
end

neotest.setup({
	adapters = adapters,
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
