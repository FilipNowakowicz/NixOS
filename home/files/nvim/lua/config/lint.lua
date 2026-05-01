local ok, lint = pcall(require, "lint")
if not ok then
	return
end

local generated = require("config.generated")

lint.linters_by_ft = generated.linters_by_ft or {}

local g = vim.api.nvim_create_augroup("lint", { clear = true })
vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "InsertLeave" }, {
	group = g,
	callback = function()
		lint.try_lint()
	end,
})
