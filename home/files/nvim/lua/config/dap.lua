-- Debugging setup: nvim-dap + dap-ui + mason-nvim-dap

local map = vim.keymap.set

-- mason-nvim-dap: installs & wires debug adapters (e.g. debugpy)
local ok_mnd, mason_nvim_dap = pcall(require, "mason-nvim-dap")
if ok_mnd then
  mason_nvim_dap.setup({
    ensure_installed = { "debugpy" }, -- Python adapter
    automatic_installation = true,
    handlers = {}, -- use default handlers
  })
end

local ok_dap, dap = pcall(require, "dap")
local ok_dapui, dapui = pcall(require, "dapui")

if ok_dap and ok_dapui then
  dapui.setup()

  -- Auto-open/close UI
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

  -------------------------------------------------------
  -- Keymaps (global)
  -------------------------------------------------------
  local opts = { noremap = true, silent = true }

  -- Basic control
  map("n", "<F5>", function() dap.continue() end, opts)
  map("n", "<F10>", function() dap.step_over() end, opts)
  map("n", "<F11>", function() dap.step_into() end, opts)
  map("n", "<F12>", function() dap.step_out() end, opts)

  -- Breakpoints
  map("n", "<leader>db", function() dap.toggle_breakpoint() end, { desc = "DAP toggle breakpoint" })
  map("n", "<leader>dB", function()
    vim.ui.input({ prompt = "Breakpoint condition: " }, function(cond)
      if cond and cond ~= "" then
        dap.set_breakpoint(cond)
      end
    end)
  end, { desc = "DAP conditional breakpoint" })

  -- REPL / last run
  map("n", "<leader>dr", function() dap.repl.open() end, { desc = "DAP REPL" })
  map("n", "<leader>dl", function() dap.run_last() end, { desc = "DAP run last" })

  -- UI toggle
  map("n", "<leader>du", function() dapui.toggle() end, { desc = "DAP UI toggle" })
end

-- NOTE: For Python, make sure debugpy is installed (mason handles it, or:
--   pip install debugpy
-- Then use <F5> in a Python file to launch debugging.
return {}
