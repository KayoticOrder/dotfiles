return {
	"shortcuts/no-neck-pain.nvim",
	-- must load at startup, or enableOnVimEnter never sees VimEnter
	lazy = false,
	opts = {
		width = 120,
		autocmds = { enableOnVimEnter = true },
	},
	keys = {
		{ "<leader>uc", "<cmd>NoNeckPain<cr>", desc = "Toggle Centered" },
	},
}
