vim.g.vimtex_view_method = "zathura"
vim.g.vimtex_compiler_method = "latexmk"
vim.g.tex_flavor = "latex"
vim.g.vimtex_quickfix_open_on_warning = 0
vim.g.vimtex_quickfix_mode = 2
vim.g.vimtex_imaps_enabled = 0
vim.g.vimtex_syntax_enabled = 0
vim.g.vimtex_compiler_latexmk = {
  options = {
    "-pdf",
    "-interaction=nonstopmode",
    "-synctex=1",
    "-outdir=build",
  },
}

local tex_group = vim.api.nvim_create_augroup("tex_qol", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = tex_group,
  pattern = { "tex", "plaintex" },
  callback = function()
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_gb"
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.formatoptions:append("t")

    vim.opt_local.conceallevel = 2
  end,
})

pcall(function()
  local npairs = require("nvim-autopairs")
  local Rule = require("nvim-autopairs.rule")
  npairs.add_rules({
    Rule("$", "$", { "tex", "plaintex" }):with_pair(function(opts)
      -- Don't pair if next char is already "$" (would create "$$$")
      -- Don't pair if already inside an odd number of "$" (inside inline math)
      local before = opts.line:sub(1, opts.col - 1)
      local after  = opts.line:sub(opts.col, opts.col)
      local count  = select(2, before:gsub("%$", ""))
      return after ~= "$" and (count % 2 == 0)
    end),
  })
end)
