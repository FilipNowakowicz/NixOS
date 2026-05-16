local function toggle_ltex()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "ltex" })
  if #clients > 0 then
    vim.cmd("LspStop ltex")
    vim.notify("LTeX: stopped")
  else
    vim.cmd("LspStart ltex")
    vim.notify("LTeX: started")
  end
end

local function toggle_conceal()
  vim.opt_local.conceallevel = (vim.opt_local.conceallevel:get() == 2) and 0 or 2
  vim.notify("Conceal: " .. vim.opt_local.conceallevel:get())
end

return {
  {
    section = "Navigation",
    mode = "n",
    lhs = "<leader>e",
    rhs = "<cmd>Oil<cr>",
    desc = "File explorer",
    opts = { silent = true },
  },
  {
    section = "Navigation",
    mode = "n",
    lhs = "-",
    rhs = "<cmd>Oil<cr>",
    desc = "Open parent directory",
    opts = { silent = true },
  },
  {
    section = "Search",
    mode = "n",
    lhs = "<leader>ff",
    rhs = function()
      require("telescope.builtin").find_files()
    end,
    desc = "Find files",
  },
  {
    section = "Search",
    mode = "n",
    lhs = "<leader>fg",
    rhs = function()
      require("telescope.builtin").live_grep()
    end,
    desc = "Live grep",
  },
  {
    section = "Search",
    mode = "n",
    lhs = "<leader>fb",
    rhs = function()
      require("telescope.builtin").buffers()
    end,
    desc = "Buffers",
  },
  {
    section = "Search",
    mode = "n",
    lhs = "<leader>fh",
    rhs = function()
      require("telescope.builtin").help_tags()
    end,
    desc = "Help tags",
  },
  {
    section = "Git",
    mode = "n",
    lhs = "]c",
    rhs = function()
      require("gitsigns").next_hunk()
    end,
    desc = "Next hunk",
  },
  {
    section = "Git",
    mode = "n",
    lhs = "[c",
    rhs = function()
      require("gitsigns").prev_hunk()
    end,
    desc = "Previous hunk",
  },
  {
    section = "Git",
    mode = "n",
    lhs = "<leader>hs",
    rhs = function()
      require("gitsigns").stage_hunk()
    end,
    desc = "Stage hunk",
  },
  {
    section = "Git",
    mode = "n",
    lhs = "<leader>hr",
    rhs = function()
      require("gitsigns").reset_hunk()
    end,
    desc = "Reset hunk",
  },
  {
    section = "Git",
    mode = "n",
    lhs = "<leader>hp",
    rhs = function()
      require("gitsigns").preview_hunk()
    end,
    desc = "Preview hunk",
  },
  {
    section = "Git",
    mode = "n",
    lhs = "<leader>hb",
    rhs = function()
      require("gitsigns").blame_line()
    end,
    desc = "Blame line",
  },
  {
    section = "Git",
    mode = "n",
    lhs = "<leader>gg",
    rhs = function()
      require("config.terminal").toggle_lazygit()
    end,
    desc = "Lazygit",
  },
  {
    section = "Editing",
    mode = "n",
    lhs = "<leader>r",
    rhs = function()
      vim.cmd("!python %")
    end,
    desc = "Run current file (python)",
    opts = { silent = true },
  },
  {
    section = "Editing",
    mode = "n",
    lhs = "<leader>m",
    rhs = "<cmd>Glow<CR>",
    desc = "Markdown preview",
    opts = { silent = true },
  },
  {
    section = "LSP",
    mode = "n",
    lhs = "gd",
    rhs = function()
      vim.lsp.buf.definition()
    end,
    desc = "Go to definition",
    event = "LspAttach",
    context = "LSP buffer",
  },
  {
    section = "LSP",
    mode = "n",
    lhs = "gD",
    rhs = function()
      vim.lsp.buf.declaration()
    end,
    desc = "Go to declaration",
    event = "LspAttach",
    context = "LSP buffer",
  },
  {
    section = "LSP",
    mode = "n",
    lhs = "gi",
    rhs = function()
      vim.lsp.buf.implementation()
    end,
    desc = "Go to implementation",
    event = "LspAttach",
    context = "LSP buffer",
  },
  {
    section = "LSP",
    mode = "n",
    lhs = "gr",
    rhs = function()
      vim.lsp.buf.references()
    end,
    desc = "Go to references",
    event = "LspAttach",
    context = "LSP buffer",
  },
  {
    section = "LSP",
    mode = "n",
    lhs = "K",
    rhs = function()
      vim.lsp.buf.hover()
    end,
    desc = "Hover",
    event = "LspAttach",
    context = "LSP buffer",
  },
  {
    section = "LSP",
    mode = "n",
    lhs = "<leader>lr",
    rhs = function()
      vim.lsp.buf.rename()
    end,
    desc = "Rename",
    event = "LspAttach",
    context = "LSP buffer",
  },
  {
    section = "LSP",
    mode = "n",
    lhs = "<leader>la",
    rhs = function()
      vim.lsp.buf.code_action()
    end,
    desc = "Code action",
    event = "LspAttach",
    context = "LSP buffer",
  },
  {
    section = "LSP",
    mode = "n",
    lhs = "<leader>lh",
    rhs = function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
    end,
    desc = "Toggle inlay hints",
  },
  {
    section = "Diagnostics",
    mode = "n",
    lhs = "<leader>ld",
    rhs = function()
      vim.diagnostic.open_float()
    end,
    desc = "Show diagnostics",
  },
  {
    section = "Diagnostics",
    mode = "n",
    lhs = "[d",
    rhs = function()
      vim.diagnostic.goto_prev()
    end,
    desc = "Previous diagnostic",
  },
  {
    section = "Diagnostics",
    mode = "n",
    lhs = "]d",
    rhs = function()
      vim.diagnostic.goto_next()
    end,
    desc = "Next diagnostic",
  },
  {
    section = "Diagnostics",
    mode = "n",
    lhs = "<leader>lq",
    rhs = function()
      vim.diagnostic.setqflist()
    end,
    desc = "List diagnostics (qf)",
  },
  {
    section = "Testing",
    mode = "n",
    lhs = "<leader>tt",
    rhs = function()
      require("neotest").run.run()
    end,
    desc = "Test nearest",
  },
  {
    section = "Testing",
    mode = "n",
    lhs = "<leader>tT",
    rhs = function()
      require("neotest").run.run(vim.fn.expand("%"))
    end,
    desc = "Test file",
  },
  {
    section = "Testing",
    mode = "n",
    lhs = "<leader>tl",
    rhs = function()
      require("neotest").run.run_last()
    end,
    desc = "Test last",
  },
  {
    section = "Testing",
    mode = "n",
    lhs = "<leader>ts",
    rhs = function()
      require("neotest").summary.toggle()
    end,
    desc = "Test summary",
  },
  {
    section = "Testing",
    mode = "n",
    lhs = "<leader>to",
    rhs = function()
      require("neotest").output_panel.toggle()
    end,
    desc = "Test output",
  },
  {
    section = "Testing",
    mode = "n",
    lhs = "<leader>tn",
    rhs = function()
      require("neotest").jump.next()
    end,
    desc = "Next test",
  },
  {
    section = "Testing",
    mode = "n",
    lhs = "<leader>tp",
    rhs = function()
      require("neotest").jump.prev()
    end,
    desc = "Prev test",
  },
  {
    section = "Debug",
    mode = "n",
    lhs = "<F5>",
    rhs = function()
      require("dap").continue()
    end,
    desc = "DAP continue",
  },
  {
    section = "Debug",
    mode = "n",
    lhs = "<F10>",
    rhs = function()
      require("dap").step_over()
    end,
    desc = "DAP step over",
  },
  {
    section = "Debug",
    mode = "n",
    lhs = "<F11>",
    rhs = function()
      require("dap").step_into()
    end,
    desc = "DAP step into",
  },
  {
    section = "Debug",
    mode = "n",
    lhs = "<F12>",
    rhs = function()
      require("dap").step_out()
    end,
    desc = "DAP step out",
  },
  {
    section = "Debug",
    mode = "n",
    lhs = "<leader>db",
    rhs = function()
      require("dap").toggle_breakpoint()
    end,
    desc = "DAP toggle breakpoint",
  },
  {
    section = "Debug",
    mode = "n",
    lhs = "<leader>dB",
    rhs = function()
      vim.ui.input({ prompt = "Breakpoint condition: " }, function(cond)
        if cond and cond ~= "" then
          require("dap").set_breakpoint(cond)
        end
      end)
    end,
    desc = "DAP conditional breakpoint",
  },
  {
    section = "Debug",
    mode = "n",
    lhs = "<leader>dr",
    rhs = function()
      require("dap").repl.open()
    end,
    desc = "DAP REPL",
  },
  {
    section = "Debug",
    mode = "n",
    lhs = "<leader>dl",
    rhs = function()
      require("dap").run_last()
    end,
    desc = "DAP run last",
  },
  {
    section = "Debug",
    mode = "n",
    lhs = "<leader>du",
    rhs = function()
      require("dapui").toggle()
    end,
    desc = "DAP UI toggle",
  },
  {
    section = "Sessions",
    mode = "n",
    lhs = "<leader>qs",
    rhs = function()
      require("persistence").load()
    end,
    desc = "Restore session",
  },
  {
    section = "Sessions",
    mode = "n",
    lhs = "<leader>ql",
    rhs = function()
      require("persistence").load({ last = true })
    end,
    desc = "Last session",
  },
  {
    section = "Sessions",
    mode = "n",
    lhs = "<leader>qd",
    rhs = function()
      require("persistence").stop()
    end,
    desc = "Don't save session",
  },
  {
    section = "Trouble",
    mode = "n",
    lhs = "<leader>xx",
    rhs = "<cmd>Trouble diagnostics toggle<cr>",
    desc = "Diagnostics",
  },
  {
    section = "Trouble",
    mode = "n",
    lhs = "<leader>xf",
    rhs = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
    desc = "Buffer diagnostics",
  },
  {
    section = "Trouble",
    mode = "n",
    lhs = "<leader>xl",
    rhs = "<cmd>Trouble lsp toggle<cr>",
    desc = "LSP references/definitions",
  },
  {
    section = "Trouble",
    mode = "n",
    lhs = "<leader>xq",
    rhs = "<cmd>Trouble qflist toggle<cr>",
    desc = "Quickfix list",
  },
  {
    section = "UI",
    mode = "n",
    lhs = "<leader>ct",
    rhs = function()
      if vim.g._copilot_disabled then
        vim.g._copilot_disabled = false
        pcall(function()
          require("copilot.command").enable()
        end)
        vim.notify("Copilot enabled")
      else
        vim.g._copilot_disabled = true
        pcall(function()
          require("copilot.command").disable()
        end)
        vim.notify("Copilot disabled")
      end
    end,
    desc = "Toggle Copilot",
  },
  {
    section = "UI",
    mode = "n",
    lhs = "gs",
    rhs = function()
      pcall(function()
        require("leap.remote").action()
      end)
    end,
    desc = "Leap remote",
  },
  {
    section = "UI",
    mode = "n",
    lhs = "]]",
    rhs = function()
      Snacks.words.jump(1, true)
    end,
    desc = "Next word occurrence",
  },
  {
    section = "UI",
    mode = "n",
    lhs = "[[",
    rhs = function()
      Snacks.words.jump(-1, true)
    end,
    desc = "Prev word occurrence",
  },
  {
    section = "UI",
    mode = "n",
    lhs = "<leader>un",
    rhs = function()
      Snacks.notifier.show_history()
    end,
    desc = "Notification history",
  },
  {
    section = "UI",
    mode = "n",
    lhs = "<C-\\>",
    rhs = "<cmd>ToggleTerm<cr>",
    desc = "Toggle terminal",
  },
  {
    section = "LaTeX",
    mode = "n",
    lhs = "<leader>vz",
    rhs = toggle_conceal,
    desc = "Toggle conceal",
    filetypes = { "tex", "plaintex" },
    context = "tex/plaintex buffer",
  },
  {
    section = "LaTeX",
    mode = "n",
    lhs = "<leader>vv",
    rhs = "<cmd>VimtexView<cr>",
    desc = "View PDF",
    filetypes = { "tex", "plaintex" },
    context = "tex/plaintex buffer",
  },
  {
    section = "LaTeX",
    mode = "n",
    lhs = "<leader>vc",
    rhs = "<cmd>VimtexCompile<cr>",
    desc = "Compile",
    filetypes = { "tex", "plaintex" },
    context = "tex/plaintex buffer",
  },
  {
    section = "LaTeX",
    mode = "n",
    lhs = "<leader>vt",
    rhs = "<cmd>VimtexTocOpen<cr>",
    desc = "TOC",
    filetypes = { "tex", "plaintex" },
    context = "tex/plaintex buffer",
  },
  {
    section = "LaTeX",
    mode = "n",
    lhs = "<leader>lg",
    rhs = toggle_ltex,
    desc = "Toggle LTeX grammar",
    enabled = "tex_grammar",
    context = "when TeX grammar is enabled",
  },
}
