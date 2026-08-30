return {
	"folke/which-key.nvim",
	"nvim-tree/nvim-web-devicons",
	{
		"numToStr/Comment.nvim",
		opts = {},
	},
	{
		"zbirenbaum/copilot.lua",
		cmd = "Copilot",
		event = "InsertEnter",
		opts = {
			-- ghost-text ready to request on demand, not shown as-you-type -
			-- blink-cmp-copilot already surfaces suggestions in the completion
			-- menu, so this covers full/multi-line suggestions on their own
			-- keys instead of fighting blink.cmp's Tab/C-* bindings for them
			suggestion = {
				enabled = true,
				auto_trigger = false,
				keymap = {
					next = "<M-\\>",
					prev = "<M-[>",
					accept = "<M-CR>",
					dismiss = "<C-]>",
				},
			},
			panel = { enabled = false },
		},
	},
	{
		"iamcco/markdown-preview.nvim",
		cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
		build = "cd app && yarn install",
		init = function()
			vim.g.mkdp_filetypes = { "markdown" }
		end,
		ft = { "markdown" },
	},
	{
		"kylechui/nvim-surround",
		version = "*", -- Use for stability; omit to use `main` branch for the latest features
		event = "VeryLazy",
		config = function()
			require("nvim-surround").setup({})
		end,
	},
	{
		"danymat/neogen",
		-- Uncomment next line if you want to follow only stable versions
		-- version = "*"
		keys = {
			{
				"<leader>cD",
				function()
					require("neogen").generate()
				end,
				desc = "Generate Doc Annotation",
			},
		},
		opts = {
			-- use Neovim's native snippet engine (vim.snippet), matching
			-- blink.cmp's snippet expansion instead of pulling in luasnip
			snippet_engine = "nvim",
		},
	},
}
