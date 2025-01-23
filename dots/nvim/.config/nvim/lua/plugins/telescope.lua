return {
	"nvim-telescope/telescope.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	cmd = "Telescope",
	keys = function()
		local tb = require("telescope.builtin")
		return {
			{ "<leader>ff", tb.find_files, desc = "Find Files" },
			{ "<leader>fg", tb.live_grep, desc = "Grep" },
			{ "<leader>fb", tb.buffers, desc = "Buffers" },
			{ "<leader>fh", tb.help_tags, desc = "Help Tags" },
			{ "<leader>fm", tb.keymaps, desc = "Keymaps" },
			{ "gd", tb.lsp_definitions, desc = "Definition" },
			{ "gD", tb.lsp_implementations, desc = "Implementation" },
			{ "gr", tb.lsp_references, desc = "References" },
		}
	end,
	config = function()
		local telescope = require("telescope")
		local actions = require("telescope.actions")
		telescope.setup({
			defaults = {
				mappings = {
					i = {
						["<C-j>"] = actions.move_selection_next,
						["<C-k>"] = actions.move_selection_previous,
						["<C-c>"] = actions.close,
					},
				},
			},
			pickers = {
				buffers = {
					mappings = {
						n = {
							["dd"] = actions.delete_buffer,
						},
					},
				},
			},
		})
	end,
}
