return {
	"nvim-tree/nvim-tree.lua",
	keys = {
		{ "<leader>nt", ":NvimTreeToggle<CR>", desc = "Toggle NvimTree" },
		{ "<leader>nf", ":NvimTreeFindFile<CR>", desc = "Find file in NvimTree" },
	},
	config = function()
		require("nvim-tree").setup({
			view = {
				side = "right",
			},
			on_attach = function(bufnr)
				local api = require("nvim-tree.api")

				local function opts(desc)
					return {
						desc = "nvim-tree: " .. desc,
						buffer = bufnr,
						noremap = true,
						silent = true,
						nowait = true,
					}
				end

				-- Default mappings
				api.config.mappings.default_on_attach(bufnr)

				-- Custom mappings
				vim.keymap.set("n", "l", api.node.open.edit, opts("Open File/Folder"))
				vim.keymap.set("n", "h", api.node.navigate.parent_close, opts("Close Folder"))
			end,
		})
	end,
}
