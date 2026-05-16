local registry = require("config.keymap_registry")
local generated = require("config.generated")

local function is_enabled(entry)
  if entry.enabled == nil then
    return true
  end
  if entry.enabled == "tex_grammar" then
    return generated.languages.tex and generated.languages.tex.grammar
  end
  if type(entry.enabled) == "function" then
    return entry.enabled()
  end
  return entry.enabled
end

local function apply_entry(entry, extra_opts)
  local opts = vim.tbl_extend("force", { desc = entry.desc }, entry.opts or {}, extra_opts or {})
  vim.keymap.set(entry.mode, entry.lhs, entry.rhs, opts)
end

for _, entry in ipairs(registry) do
  if is_enabled(entry) and not entry.event and not entry.filetypes then
    apply_entry(entry)
  end
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    for _, entry in ipairs(registry) do
      if is_enabled(entry) and entry.event == "LspAttach" then
        apply_entry(entry, { buffer = args.buf })
      end
    end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "tex", "plaintex" },
  callback = function(args)
    for _, entry in ipairs(registry) do
      if is_enabled(entry) and entry.filetypes and vim.tbl_contains(entry.filetypes, args.match) then
        apply_entry(entry, { buffer = args.buf })
      end
    end
  end,
})
