local ok, conform = pcall(require, "conform")
if not ok then
  return
end

conform.setup({
  formatters_by_ft = {
    python = { "ruff_format" },
    nix    = { "nixfmt" },
    lua    = { "stylua" },
  },
  format_on_save = {
    timeout_ms = 500,
    lsp_fallback = true,
  },
})

vim.keymap.set({ "n", "v" }, "<leader>lf", function()
  conform.format({ async = true, lsp_fallback = true })
end, { desc = "Format" })
