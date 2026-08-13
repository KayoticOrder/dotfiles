return {
	"Isrothy/neominimap.nvim",
	version = "v3.x.x",
	lazy = false, -- NOTE: NO NEED to Lazy load
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"lewis6991/gitsigns.nvim",
	},
	init = function()
		-- Recommended when layout == "float"
		vim.opt.wrap = false
		vim.opt.sidescrolloff = 36

		---@type Neominimap.UserConfig
		vim.g.neominimap = {
			auto_enable = false, -- start closed; toggle with <leader>um
			layout = "float",
			float = {
				minimap_width = 10,
			},
			exclude_filetypes = { "help", "bigfile" },
			search = { enabled = true },
		}
	end,
	keys = {
		{ "<leader>um", "<cmd>Neominimap Toggle<cr>", desc = "Toggle Minimap" },
	},
}
