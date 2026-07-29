return {
	"nvim-treesitter/nvim-treesitter-textobjects",
	branch = "main",
	lazy = true,
	config = function()
		require("nvim-treesitter-textobjects").setup({
			select = {
				lookahead = true,
			},
		})

		local select_textobject = require("nvim-treesitter-textobjects.select").select_textobject

		local function map(keys, query)
			vim.keymap.set({ "x", "o" }, keys, function()
				select_textobject(query, "textobjects")
			end)
		end

		map("af", "@function.outer")
		map("if", "@function.inner")

		map("ac", "@class.outer")
		map("ic", "@class.inner")

		map("al", "@loop.outer")
		map("il", "@loop.inner")

		map("ai", "@conditional.outer")
		map("ii", "@conditional.inner")
	end,
}
