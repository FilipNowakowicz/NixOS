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
    vim.keymap.set("n", "<leader>tc", function()
      vim.opt_local.conceallevel = (vim.opt_local.conceallevel:get() == 2) and 0 or 2
      vim.notify("Conceal: " .. vim.opt_local.conceallevel:get())
    end, { buffer = true, desc = "Toggle conceal" })

    vim.keymap.set("n", "<leader>vv", "<cmd>VimtexView<cr>", { buffer = true, desc = "View PDF" })
    vim.keymap.set("n", "<leader>vc", "<cmd>VimtexCompile<cr>", { buffer = true, desc = "Compile" })
    vim.keymap.set("n", "<leader>vt", "<cmd>VimtexTocOpen<cr>", { buffer = true, desc = "TOC" })
  end,
})

pcall(function()
  local npairs = require("nvim-autopairs")
  local Rule = require("nvim-autopairs.rule")
  npairs.add_rules({
    Rule("$", "$", { "tex", "plaintex" }):with_pair(function(opts)
      local line = opts.line
      local before = line:sub(1, opts.col - 1)
      local after = line:sub(opts.col, opts.col)
      local double_dollar = before:match("%$%$") or after == "$"
      return double_dollar or false
    end),
  })
end)
