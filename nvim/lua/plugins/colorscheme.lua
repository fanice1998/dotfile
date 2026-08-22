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
