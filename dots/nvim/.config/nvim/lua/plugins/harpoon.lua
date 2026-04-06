return {
	"https://github.com/theprimeagen/harpoon",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	keys = {
		{
			"<leader>ha",
			function()
				require("harpoon.mark").add_file()
			end,
			desc = "Add File",
		},
		{
			"<leader>hh",
			function()
				require("harpoon.ui").toggle_quick_menu()
			end,
			desc = "Menu",
		},
		{
			"]h",
			function()
				require("harpoon.ui").nav_next()
			end,
			desc = "Next Harpoon File",
		},
		{
			"[h",
			function()
				require("harpoon.ui").nav_prev()
			end,
			desc = "Prev Harpoon File",
		},
		{
			"<leader>1",
			function()
				require("harpoon.ui").nav_file(1)
			end,
			desc = "Harpoon File 1",
		},
		{
			"<leader>2",
			function()
				require("harpoon.ui").nav_file(2)
			end,
			desc = "Harpoon File 2",
		},
		{
			"<leader>3",
			function()
				require("harpoon.ui").nav_file(3)
			end,
			desc = "Harpoon File 3",
		},
		{
			"<leader>4",
			function()
				require("harpoon.ui").nav_file(4)
			end,
			desc = "Harpoon File 4",
		},
		{
			"<leader>5",
			function()
				require("harpoon.ui").nav_file(5)
			end,
			desc = "Harpoon File 5",
		},
	},
	config = function()
		require("harpoon").setup({
			global_settings = {
				save_on_toggle = true,
				save_on_change = true,
				enter_on_sendcmd = false,
				mark_branch = true,
				excluded_filetypes = {
					"harpoon",
					"TelescopePrompt",
					"neo-tree",
					"NvimTree",
					"help",
				},
			},
			menu = {
				width = math.min(vim.api.nvim_win_get_width(0) - 4, 100),
			},
		})
	end,
}
