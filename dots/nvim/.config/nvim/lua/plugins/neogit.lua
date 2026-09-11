return {
	"NeogitOrg/neogit",
	dependencies = {
		"nvim-lua/plenary.nvim",
		-- already installed for <leader>gH; neogit uses it for commit diffs
		"dlyongemallo/diffview.nvim",
		"nvim-tree/nvim-web-devicons",
	},
	cmd = "Neogit",
	keys = {
		{
			"<leader>gg",
			function()
				require("neogit").open()
			end,
			desc = "Neogit Status",
		},
	},
	opts = {},
}
