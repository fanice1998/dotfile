-- ~/.config/nvim/lua/plugins/colorscheme.lua
return {
  -- override tokyonight 的 opts (會覆蓋/lazyVim 預設的)
  {
    "folke/tokyonight.nvim",
    opts = {
      transparent = true,
      style = "moon",
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },
}
