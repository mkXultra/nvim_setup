return {
	-- Neovim 0.11向けの互換ブランチ。Markdownと画像リンクの解析に使用。
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "master",
		lazy = false,
		build = ":TSUpdate",
		opts = {
			ensure_installed = { "markdown", "markdown_inline", "html" },
			auto_install = false,
			highlight = { enable = true },
		},
		config = function(_, opts)
			require("nvim-treesitter.configs").setup(opts)
		end,
	},
	-- 見出し・表・チェックボックスをバッファ内で表示。
	{
		"MeanderingProgrammer/render-markdown.nvim",
		ft = { "markdown" },
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"nvim-tree/nvim-web-devicons",
		},
		opts = {
			latex = { enabled = false },
		},
		keys = {
			{ "<leader>mr", "<cmd>RenderMarkdown toggle<cr>", ft = "markdown", desc = "Toggle Markdown rendering" },
			{ "<leader>mp", "<cmd>RenderMarkdown preview<cr>", ft = "markdown", desc = "Markdown side preview" },
		},
	},
	-- Ghostty / Kittyで画像とMermaidを表示（ImageMagickとmmdcが必要）。
	{
		"folke/snacks.nvim",
		priority = 1000,
		lazy = false,
		opts = {
			image = {
				enabled = true,
				math = { enabled = false },
			},
		},
		keys = {
			{
				"<leader>mi",
				function()
					Snacks.image.hover()
				end,
				ft = "markdown",
				desc = "Preview image or Mermaid at cursor",
			},
		},
	},
}
