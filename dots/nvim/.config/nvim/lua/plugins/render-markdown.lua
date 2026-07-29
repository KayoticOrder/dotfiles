return {
	"MeanderingProgrammer/render-markdown.nvim",
	ft = { "markdown" },
	dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
	config = function()
		-- Matches the checkbox states obsidian.nvim's own UI used to render
		-- before it was disabled in favor of this plugin (see obsidian.lua).
		vim.api.nvim_set_hl(0, "RenderMarkdownInProgress", { fg = "#ff5370", bold = true })
		vim.api.nvim_set_hl(0, "RenderMarkdownImportant", { fg = "#d73128", bold = true })
		vim.api.nvim_set_hl(0, "RenderMarkdownForwarded", { fg = "#f78c6c", bold = true })

		require("render-markdown").setup({
			checkbox = {
				custom = {
					in_progress = { raw = "[~]", rendered = "󰰱 ", highlight = "RenderMarkdownInProgress" },
					important = { raw = "[!]", rendered = " ", highlight = "RenderMarkdownImportant" },
					forwarded = { raw = "[>]", rendered = " ", highlight = "RenderMarkdownForwarded" },
				},
			},
		})
	end,
}
