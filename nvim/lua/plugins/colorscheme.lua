-- ~/.config/nvim/lua/plugins/colorscheme.lua
return {
  -- 關掉 tokyonight
  { "folke/tokyonight.nvim", enabled = false },

  -- 安裝 Everforest
  {
    "sainnhe/everforest",
    lazy = false,
    priority = 1000,
    init = function()
      vim.g.everforest_background = "medium" -- soft / medium / hard
      vim.g.everforest_enable_italic = 1
      vim.g.everforest_better_performance = 1

      -- Enable transparent background
      -- 1. Transparent background and sider.
      -- 2. The background, sider, and floating windows are all transparent.
      vim.g.everforest_transparent_background = 2
    end,
    config = function()
      -- Apply color theme
      vim.cmd.colorscheme("everforest")

      -- Clear the background color of LazyVim floating terminal and floating window
      local function clear_terminal_bg()
        local term_groups = {
          "Normal",
          "NormalNC",
          "NormalFloat",
          "FloatBorder",
          "FloatTitle",
          "TermNormal",
          "TermNormalNC",
          "EndOfBuffer",
          "SignColumn",
          "SnacksTerminal",
          "SnacksTerminalBorder",
          "SnacksNormal",
          "SnacksNormalNC",
        }

        for _, group in ipairs(term_groups) do
          vim.api.nvim_set_hl(0, group, { bg = "NONE", ctermbg = "NONE" })
        end
      end

      clear_terminal_bg()

      vim.api.nvim_create_autocmd({ "TermOpen", "BufEnter" }, {
        pattern = "*",
        callback = function()
          if vim.bo.buftype == "terminal" then
            vim.opt_local.winhighlight = "Normal:Normal,NormalNC:NormalNC"
          end
          clear_terminal_bg()
        end,
      })
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
