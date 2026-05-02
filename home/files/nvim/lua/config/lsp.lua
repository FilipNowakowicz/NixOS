-----------------------------------------------------------
-- Copilot toggle on <leader>ct
-----------------------------------------------------------
local generated = require("config.generated")

vim.keymap.set("n", "<leader>ct", function()
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
end, { desc = "Toggle Copilot" })

-----------------------------------------------------------
-- LSP (Neovim 0.11+ API)
-----------------------------------------------------------
local capabilities = require("blink.cmp").get_lsp_capabilities()

vim.lsp.config("clangd", { capabilities = capabilities })

local enabled_servers = { "clangd" }
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
		local opts = { buffer = buf, silent = true, noremap = true }
		local map = vim.keymap.set

		map("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Go to definition" }))
		map("n", "gD", vim.lsp.buf.declaration, vim.tbl_extend("force", opts, { desc = "Go to declaration" }))
		map("n", "gi", vim.lsp.buf.implementation, vim.tbl_extend("force", opts, { desc = "Go to implementation" }))
		map("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { desc = "Go to references" }))
		map("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Hover" }))
		map("n", "<leader>lr", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Rename" }))
		map("n", "<leader>la", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "Code action" }))

		if vim.lsp.inlay_hint then
			vim.lsp.inlay_hint.enable(true, { bufnr = buf })
		end
	end,
})

vim.keymap.set("n", "<leader>lh", function()
	vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, { desc = "Toggle inlay hints" })

-----------------------------------------------------------
-- Diagnostics keymaps
-----------------------------------------------------------
vim.keymap.set("n", "<leader>ld", vim.diagnostic.open_float, { desc = "Show diagnostics" })
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
vim.keymap.set("n", "<leader>lq", vim.diagnostic.setqflist, { desc = "List diagnostics (qf)" })
