local ok, lint = pcall(require, "lint")
if not ok then
  return
end

lint.linters_by_ft = {
  python = { "flake8" },
}

local g = vim.api.nvim_create_augroup("lint", { clear = true })
vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "InsertLeave" }, {
  group = g,
  callback = function()
    lint.try_lint()
  end,
})

