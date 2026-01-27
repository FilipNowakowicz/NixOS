-- lazy.nvim bootstrap + plugin spec

vim.opt.rtp:prepend("~/.config/nvim/lazy/lazy.nvim")

require("lazy").setup({
  ---------------------------------------------------------------
  -- Colorschemes
  ---------------------------------------------------------
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 1000,
  },
  {
    "vague-theme/vague.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      -- pick your default here:
      vim.cmd.colorscheme("vague")
      -- or:
      -- vim.cmd.colorscheme("kanagawa")
    end,
  },

  ---------------------------------------------------
  -- LSP & Completion
  ---------------------------------------------------------
  "neovim/nvim-lspconfig",
  "williamboman/mason.nvim",
  "williamboman/mason-lspconfig.nvim",

  "hrsh7th/nvim-cmp",
  "hrsh7th/cmp-nvim-lsp",
  "hrsh7th/cmp-buffer",
  "hrsh7th/cmp-path",
  "saadparwaiz1/cmp_luasnip",
  "L3MON4D3/LuaSnip",

  -- Copilot (inline ghost text; NO cmp bridge)
  {
    "zbirenbaum/copilot.lua",
    event = "InsertEnter",
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept      = "<C-l>",
          accept_line = "<C-j>",
          next        = "<M-]>",
          prev        = "<M-[>",
          dismiss     = "<C-]>",
        },
      },
      panel = { enabled = false },
      filetypes = {
        markdown = true,
      },
    },
  },

  -- Python linting on save
  {
    "mfussenegger/nvim-lint",
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        python = { "flake8" },
      }

      vim.api.nvim_create_autocmd({ "BufWritePost" }, {
        callback = function()
          lint.try_lint()
        end,
      })
    end,
  },

  ---------------------------------------------------------
  -- Debugging & Tests
  ---------------------------------------------------------
  "mfussenegger/nvim-dap",
  "rcarriga/nvim-dap-ui",
  "jay-babu/mason-nvim-dap.nvim",
  "nvim-neotest/neotest",
  "nvim-neotest/neotest-python",

  ---------------------------------------------------------
  -- UI & Navigation
  ---------------------------------------------------------
  "nvim-lualine/lualine.nvim",
  "nvim-tree/nvim-tree.lua",
  
  "nvim-treesitter/nvim-treesitter",
  "nvim-treesitter/nvim-treesitter-textobjects",
  
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make", -- REQUIRED
      },
    },
  },

  "ggandor/leap.nvim",

  ---------------------------------------------------------
  -- Git
  ---------------------------------------------------------
  "lewis6991/gitsigns.nvim",
  "tpope/vim-fugitive",

  ---------------------------------------------------------
  -- Quality of life
  ---------------------------------------------------------
  { "numToStr/Comment.nvim", config = true },
  { "windwp/nvim-autopairs", config = true },
  { "kylechui/nvim-surround", config = true },
  { "folke/trouble.nvim", config = true },
  { "folke/which-key.nvim", config = true },
  { "lukas-reineke/indent-blankline.nvim", main = "ibl", config = true },

  ---------------------------------------------------------
  -- Markdown preview
  ---------------------------------------------------------
  { "ellisonleao/glow.nvim", config = true, cmd = "Glow" },

  ---------------------------------------------------------
  -- LaTeX stack
  ---------------------------------------------------------
  { "lervag/vimtex", ft = { "tex", "plaintex" } },
  { "hrsh7th/cmp-omni" },
  { "kdheepak/cmp-latex-symbols" },
}, {
})

return {}

