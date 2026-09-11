return {
	-- sindrets/diffview.nvim is unmaintained since mid-2024; this fork has
	-- ongoing bug fixes and is API-compatible (same commands/keymaps)
	"dlyongemallo/diffview.nvim",
	cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
	keys = {
		{ "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff View Open" },
		{ "<leader>gD", "<cmd>DiffviewClose<cr>", desc = "Diff View Close" },
		{ "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "File History" },
	},
}
