return {
	"nvim-treesitter/nvim-treesitter-textobjects",
	lazy = true,
	config = function()
		require("nvim-treesitter.configs").setup({
			textobjects = {
				select = {
					enable = true,
					lookahead = true,
					keymaps = {
						["af"] = { query = "@function.outer", desc = "Select function" },
						["if"] = { query = "@function.inner", desc = "Select inner function" },

						["ac"] = { query = "@class.outer", desc = "Select class" },
						["ic"] = { query = "@class.inner", desc = "Select inner class" },

						["al"] = { query = "@loop.outer", desc = "Select loop" },
						["il"] = { query = "@loop.inner", desc = "Select inner loop" },

						["ai"] = { query = "@conditional.outer", desc = "Select conditional" },
						["ii"] = { query = "@conditional.inner", desc = "Select inner conditional" },
					},
				},
			},
		})
	end,
}
