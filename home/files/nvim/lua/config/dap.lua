local map = vim.keymap.set

local ok_mnd, mason_nvim_dap = pcall(require, "mason-nvim-dap")
if ok_mnd then
  mason_nvim_dap.setup({
    ensure_installed = {},
    automatic_installation = false,
    handlers = {},
  })
end

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

dap.configurations.python = {
  {
    type = "python",
    request = "launch",
    name = "Launch file",
    program = "${file}",
    pythonPath = function()
      return (vim.fn.exepath("python3") ~= "" and "python3") or "python"
    end,
  },
}

local opts = { silent = true }

map("n", "<F5>", function()
  dap.continue()
end, opts)
map("n", "<F10>", function()
  dap.step_over()
end, opts)
map("n", "<F11>", function()
  dap.step_into()
end, opts)
map("n", "<F12>", function()
  dap.step_out()
end, opts)

map("n", "<leader>db", function()
  dap.toggle_breakpoint()
end, { desc = "DAP toggle breakpoint" })

map("n", "<leader>dB", function()
  vim.ui.input({ prompt = "Breakpoint condition: " }, function(cond)
    if cond and cond ~= "" then
      dap.set_breakpoint(cond)
    end
  end)
end, { desc = "DAP conditional breakpoint" })

map("n", "<leader>dr", function()
  dap.repl.open()
end, { desc = "DAP REPL" })

map("n", "<leader>dl", function()
  dap.run_last()
end, { desc = "DAP run last" })

map("n", "<leader>du", function()
  dapui.toggle()
end, { desc = "DAP UI toggle" })
