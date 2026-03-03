return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    version = false, -- 保持最新
    build = "make", -- 重要：建置 binary
    opts = {
      provider = "grok", -- 預設用 openai，之後改 grok
      providers = {
        grok = {
          __inherited_from = "openai",
          endpoint = "https://api.x.ai/v1",
          model = "grok-4-1-fast-non-reasoning",
          api_key_name = "XAI_API_KEY",
        },
      },
    },
    dependencies = {
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      --- 可選，但強烈建議裝
      "nvim-tree/nvim-web-devicons",
      {
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = { default = { embed_image_as_base64 = false, drag_and_drop = { insert_mode = true } } },
      },
      {
        "MeanderingProgrammer/render-markdown.nvim",
        opts = { file_types = { "markdown", "Avante" } },
        ft = { "markdown", "Avante" },
      },
    },
  },
}
