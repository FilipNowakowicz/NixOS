local generated = require("config.generated")

-----------------------------------------------------------
-- LSP (Neovim 0.11+ API)
-----------------------------------------------------------
local capabilities = require("blink.cmp").get_lsp_capabilities()

local enabled_servers = {}
for _, server in ipairs(generated.lsp.enable or {}) do
	local server_settings = generated.lsp.settings and generated.lsp.settings[server]
	vim.lsp.config(
		server,
		vim.tbl_extend("force", {
			capabilities = capabilities,
		}, server_settings and { settings = server_settings } or {})
	)
	table.insert(enabled_servers, server)
end

vim.lsp.enable(enabled_servers)

-- LTeX (lazy-start, toggled manually with <leader>lg)
if generated.languages.tex and generated.languages.tex.grammar then
	local java_opts = "-Djdk.xml.totalEntitySizeLimit=0 --enable-native-access=ALL-UNNAMED"
	vim.lsp.config("ltex", {
		autostart = false,
		cmd = { "ltex-ls-plus" },
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
end

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
		if vim.lsp.inlay_hint then
			vim.lsp.inlay_hint.enable(true, { bufnr = buf })
		end
	end,
})
