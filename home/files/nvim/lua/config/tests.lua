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
