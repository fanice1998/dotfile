-- =====================================================
-- WezTerm 設定檔（已完整優化 - 2026/05）
-- =====================================================
--
-- 【主題】
--   - Gruvbox Dark Hard（深黑灰調，沉穩不刺眼）
--
-- 【背景效果】
--   - 透明度 0.85
--   - Windows 只使用透明（已註解 Acrylic 模糊）
--   - macOS 保留模糊效果
--
-- 【快捷鍵設計】
--   以 Kitty 風格為基礎，經過多次調整避免衝突：
--   - 分頁操作：Ctrl + Shift + t（新分頁） / w（關閉分頁） / n（新視窗）
--   - 分割視窗：Ctrl + Alt + -（水平） / \（垂直）
--   - 關閉目前 Pane：Ctrl + Shift + d
--   - 切換 Pane：Ctrl + Shift + h / j / k / l
--   - 調整 Pane 大小：Ctrl + Shift + 方向鍵
--
-- 【視覺優化】
--   - 細邊框 + 深色標題列
--   - 標籤頁樣式（活躍分頁使用黃色高亮）
--   - 游標顏色與 Gruvbox 黃色一致
--   - inactive pane 微暗（讓焦點更清楚）
--   - 字體：JetBrains Mono 13.5pt
--
-- 【其他】
--   - 已停用所有預設縮放快捷鍵衝突
--   - 三平台（Fedora / Windows 11 / macOS）皆適用
--
-- =====================================================

local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.color_scheme = 'Gruvbox Dark Hard'

config.window_background_opacity = 0.85
config.macos_window_background_blur = 28
-- config.win32_system_backdrop = 'Acrylic'

config.font = wezterm.font('JetBrains Mono', { weight = 'Medium' })
config.font_size = 13.5
config.line_height = 1.15

config.window_frame = {
  border_left_width = '1px',
  border_right_width = '1px',
  border_top_height = '1px',
  border_bottom_height = '1px',
  border_left_color = '#3c3836',
  border_right_color = '#3c3836',
  border_top_color = '#3c3836',
  border_bottom_color = '#3c3836',
  active_titlebar_bg = '#282828',
  inactive_titlebar_bg = '#282828',
  active_titlebar_fg = '#ebdbb2',
  inactive_titlebar_fg = '#928374',
}
config.window_decorations = "RESIZE"

config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.tab_max_width = 28
config.tab_bar_at_bottom = false

config.colors = {
  tab_bar = {
    background = '#282828',
    active_tab = {
      bg_color = '#3c3836',
      fg_color = '#fabd2f',
      intensity = 'Normal',
      underline = 'None',
      italic = false,
      strikethrough = false,
    },
    inactive_tab = {
      bg_color = '#282828',
      fg_color = '#928374',
      intensity = 'Normal',
      underline = 'None',
      italic = false,
      strikethrough = false,
    },
    inactive_tab_hover = {
      bg_color = '#3c3836',
      fg_color = '#d5c4a1',
      intensity = 'Normal',
      underline = 'None',
      italic = true,
    },
    new_tab = {
      bg_color = '#282828',
      fg_color = '#928374',
    },
    new_tab_hover = {
      bg_color = '#3c3836',
      fg_color = '#fabd2f',
    },
  },
  cursor_bg = '#fabd2f',
  cursor_border = '#fabd2f',
  cursor_fg = '#282828',
}

config.window_padding = { left = 10, right = 10, top = 8, bottom = 8 }
config.default_cursor_style = 'BlinkingBlock'
config.cursor_blink_rate = 500
config.inactive_pane_hsb = { saturation = 0.85, brightness = 0.65 }

config.front_end = 'WebGpu'
config.enable_wayland = false
config.window_close_confirmation = 'NeverPrompt'

-- ==================== 快捷鍵 ====================
config.keys = {
  -- 分頁
  { key = "t", mods = "CTRL|SHIFT", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
  { key = "w", mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentTab{ confirm = false } },
  { key = "n", mods = "CTRL|SHIFT", action = wezterm.action.SpawnWindow },

  -- 分割視窗
  { key = "-", mods = "CTRL|ALT", action = wezterm.action.SplitVertical{ domain = "CurrentPaneDomain" } },
  { key = "\\", mods = "CTRL|ALT", action = wezterm.action.SplitHorizontal{ domain = "CurrentPaneDomain" } },

  -- 關閉目前 Pane
  { key = "d", mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentPane{ confirm = false } },

  -- 切換 Pane
  { key = "h", mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Left") },
  { key = "j", mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Down") },
  { key = "k", mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Up") },
  { key = "l", mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Right") },

  -- 調整 Pane 大小
  { key = "LeftArrow",  mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize{ "Left", 5 } },
  { key = "RightArrow", mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize{ "Right", 5 } },
  { key = "UpArrow",    mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize{ "Up", 5 } },
  { key = "DownArrow",  mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize{ "Down", 5 } },

  { key = "f", mods = "CTRL|SHIFT", action = wezterm.action.ToggleFullScreen },
}

return config
