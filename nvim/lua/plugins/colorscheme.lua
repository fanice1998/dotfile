-- ~/.config/nvim/lua/plugins/colorscheme.lua
return {
  -- override everforest 的 opts (會覆蓋/lazyVim 預設的)
  {
    "sainnhe/everforest",
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
