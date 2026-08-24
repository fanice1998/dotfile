-- ~/.config/nvim/lua/plugins/colorscheme.lua
return {
  -- 關掉 tokyonight
  { "folke/tokyonight.nvim", enabled = false },

  -- 安裝 Everforest
  {
    "sainnhe/everforest",
    lazy = false,
    priority = 1000,
    config = function()
      vim.g.everforest_background = "medium" -- soft / medium / hard
      vim.g.everforest_enable_italic = 1
      vim.g.everforest_better_performance = 1

      -- Enable transparent background
      -- 1. Transparent background and sider.
      -- 2. The background, sider, and floating windows are all transparent.
      vim.g.everforest_transparent_background = 2

      -- Apply color theme
      vim.cmd.colorscheme("everforest")
    end,
  },

  -- 關鍵：強制覆蓋 LazyVim 的預設主題
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "everforest",
    },
  },
}
