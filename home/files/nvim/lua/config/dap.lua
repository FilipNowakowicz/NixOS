local generated = require("config.generated")
local ok_dap, dap = pcall(require, "dap")
local ok_dapui, dapui = pcall(require, "dapui")
if not (ok_dap and ok_dapui) then
	return
end

dapui.setup()

dap.listeners.before.attach.dapui_config = function()
	dapui.open()
end
dap.listeners.before.launch.dapui_config = function()
	dapui.open()
end
dap.listeners.before.event_terminated.dapui_config = function()
	dapui.close()
end
dap.listeners.before.event_exited.dapui_config = function()
	dapui.close()
end

for filetype, configs in pairs((generated.dap and generated.dap.configurations) or {}) do
	dap.configurations[filetype] = vim.tbl_map(function(configuration)
		if configuration.type == "python" and configuration.useSystemPython then
			configuration.pythonPath = function()
				return (vim.fn.exepath("python3") ~= "" and "python3") or "python"
			end
			configuration.useSystemPython = nil
		end
		return configuration
	end, configs)
end
