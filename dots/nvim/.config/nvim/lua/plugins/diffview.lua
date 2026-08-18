return {
	"sindrets/diffview.nvim",
	cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
	keys = {
		{ "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff View Open" },
		{ "<leader>gD", "<cmd>DiffviewClose<cr>", desc = "Diff View Close" },
		{ "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "File History" },
	},
}
