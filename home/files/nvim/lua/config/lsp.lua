-- Mason + LSP + cmp + diagnostics

-----------------------------------------------------------
-- Mason
-----------------------------------------------------------
local ok_mason, mason = pcall(require, "mason")
if ok_mason then
  mason.setup()
end

local ok_mlsp, mason_lspconfig = pcall(require, "mason-lspconfig")
if ok_mlsp then
  mason_lspconfig.setup({
    ensure_installed = { "clangd", "basedpyright", "ltex" },
    automatic_installation = true,
  })
end

-----------------------------------------------------------
-- Copilot toggle on <leader>ct
-----------------------------------------------------------
vim.keymap.set("n", "<leader>ct", function()
  if vim.g._copilot_disabled then
    vim.g._copilot_disabled = false
    pcall(function() require("copilot.command").enable() end)
    vim.notify("Copilot enabled")
  else
    vim.g._copilot_disabled = true
    pcall(function() require("copilot.command").disable() end)
    vim.notify("Copilot disabled")
  end
end, { desc = "Toggle Copilot" })

-----------------------------------------------------------
-- LSP (Neovim 0.11+ API)
-----------------------------------------------------------
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- clangd
vim.lsp.config("clangd", {
  capabilities = capabilities,
})

-- basedpyright
vim.lsp.config("basedpyright", {
  capabilities = capabilities,
  settings = {
    basedpyright = {
      typeCheckingMode = "basic",
      reportUnknownParameterType = "none",
      reportUnknownArgumentType = "none",
      reportUnknownVariableType = "none",
      reportUnknownMemberType = "none",
      reportMissingTypeStubs = "none",
    },
  },
})

vim.lsp.enable({ "clangd", "basedpyright" })

-- LTeX (do NOT autostart; we toggle it)
local java_opts = "-Djdk.xml.totalEntitySizeLimit=0 --enable-native-access=ALL-UNNAMED"

vim.lsp.config("ltex", {
  autostart = false,
  cmd_env = {
    JAVA_TOOL_OPTIONS = ((vim.env.JAVA_TOOL_OPTIONS or "") .. " " .. java_opts),
  },
  settings = {
    ltex = {
      language = "en-GB",
      additionalRules = { enablePickyRules = false },
    },
  },
})

-- Toggle LTeX on current buffer: <Space>lg
vim.keymap.set("n", "<leader>lg", function()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "ltex" })
  if #clients > 0 then
    vim.cmd("LspStop ltex")
    vim.notify("LTeX: stopped")
  else
    vim.cmd("LspStart ltex")
    vim.notify("LTeX: started")
  end
end, { desc = "Toggle LTeX grammar" })

-----------------------------------------------------------
-- Global diagnostic config
-----------------------------------------------------------
vim.diagnostic.config({
  virtual_text = false,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

-- LSP keymaps per buffer
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local buf = args.buf
    local opts = { buffer = buf, silent = true, noremap = true }

    local map = vim.keymap.set
    map("n", "gd", vim.lsp.buf.definition, opts)
    map("n", "gD", vim.lsp.buf.declaration, opts)
    map("n", "gi", vim.lsp.buf.implementation, opts)
    map("n", "gr", vim.lsp.buf.references, opts)
    map("n", "K", vim.lsp.buf.hover, opts)
    map("n", "<leader>rn", vim.lsp.buf.rename, opts)
    map("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    map("n", "<leader>f", function()
      vim.lsp.buf.format({ async = true })
    end, opts)
  end,
})

-----------------------------------------------------------
-- nvim-cmp (with LuaSnip; Copilot handled separately)
-----------------------------------------------------------
local cmp = require("cmp")
local luasnip = require("luasnip")

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-Space>"] = cmp.mapping.complete(),

    ["<CR>"] = cmp.mapping(function(fallback)
      if cmp.visible() and cmp.get_selected_entry() then
        cmp.confirm({ select = false })
      else
        fallback()
      end
    end, { "i", "s" }),

    ["<Tab>"] = cmp.mapping(function(fallback)
      local ok, suggestion = pcall(require, "copilot.suggestion")
      if ok and suggestion.is_visible() then
        suggestion.accept_word()
      elseif cmp.visible() then
        cmp.select_next_item()
      else
        fallback()
      end
    end, { "i", "s" }),

    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      else
        fallback()
      end
    end, { "i", "s" }),

    ["<C-y>"] = cmp.mapping.confirm({ select = false }),
    ["<C-e>"] = cmp.mapping.abort(),
    ["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
    ["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
  }),

  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "luasnip" },
    { name = "path" },
    { name = "buffer" },
  }),
})

-- TeX-specific cmp sources (omni, latex symbols, bibtex)
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "tex", "plaintex" },
  callback = function()
    local ok, cmp2 = pcall(require, "cmp")
    if not ok then
      return
    end
    cmp2.setup.buffer({
      sources = cmp2.config.sources({
        { name = "omni" },
        { name = "latex_symbols" },
        { name = "nvim_lsp" },
        { name = "luasnip" },
        { name = "buffer" },
        { name = "path" },
      }),
    })
  end,
})

-- autopairs on confirm
pcall(function()
  local cmp_autopairs = require("nvim-autopairs.completion.cmp")
  cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
end)

-----------------------------------------------------------
-- Diagnostics keymaps (global)
-----------------------------------------------------------
vim.keymap.set("n", "<leader>k", vim.diagnostic.open_float, { desc = "Show diagnostics" })
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setqflist, { desc = "List diagnostics" })

return {}

