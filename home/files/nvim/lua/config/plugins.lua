local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { "rebelot/kanagawa.nvim", lazy = false, priority = 1000 },
  { "vague-theme/vague.nvim", lazy = false, priority = 1000 },

  { "nvim-tree/nvim-web-devicons", lazy = true },

  { "neovim/nvim-lspconfig" },
  { "williamboman/mason.nvim" },
  { "williamboman/mason-lspconfig.nvim" },

  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "hrsh7th/cmp-buffer" },
  { "hrsh7th/cmp-path" },
  { "saadparwaiz1/cmp_luasnip" },
  { "L3MON4D3/LuaSnip" },

  {
    "zbirenbaum/copilot.lua",
    event = "InsertEnter",
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = "<C-l>",
          accept_line = "<C-j>",
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<C-]>",
        },
      },
      panel = { enabled = false },
      filetypes = { markdown = true },
    },
  },

  { "mfussenegger/nvim-lint" },

  { "mfussenegger/nvim-dap" },
  { "nvim-neotest/nvim-nio" },
  { "rcarriga/nvim-dap-ui" },
  { "jay-babu/mason-nvim-dap.nvim" },

  { "nvim-neotest/neotest" },
  { "nvim-neotest/neotest-python" },

  { "nvim-lualine/lualine.nvim" },
  { "nvim-tree/nvim-tree.lua" },

  -- { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
  -- { "nvim-treesitter/nvim-treesitter" },
  -- { "nvim-treesitter/nvim-treesitter-textobjects", dependencies = { "nvim-treesitter/nvim-treesitter" } },

  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
  },

  -- { "nvim-lua/plenary.nvim" },

  { url = "https://codeberg.org/andyg/leap.nvim" },

  { "lewis6991/gitsigns.nvim" },
  { "tpope/vim-fugitive" },

  { "numToStr/Comment.nvim" },
  { "windwp/nvim-autopairs" },
  { "kylechui/nvim-surround" },
  { "folke/trouble.nvim" },
  { "folke/which-key.nvim" },
  { "lukas-reineke/indent-blankline.nvim", main = "ibl" },

  { "ellisonleao/glow.nvim", cmd = "Glow" },

  { "lervag/vimtex", ft = { "tex", "plaintex" } },
  { "hrsh7th/cmp-omni" },
  { "kdheepak/cmp-latex-symbols" },
}, {
  -- For NixOS compatibility
  lockfile = vim.fn.stdpath("data") .. "/lazy/lazy-lock.json",

  checker = { enabled = false },
  change_detection = { notify = false },
})
