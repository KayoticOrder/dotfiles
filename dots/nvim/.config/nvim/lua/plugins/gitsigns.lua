return {
	"lewis6991/gitsigns.nvim",
	lazy = false,
	opts = {},
	keys = {
    -- stylua: ignore start
    { "<leader>ghp", mode = { "n" }, function() require("gitsigns").preview_hunk() end, desc = "Preview Hunk" },
    { "<leader>ghs", mode = { "n" }, function() require("gitsigns").stage_hunk() end, desc = "Stage Hunk" },
    { "<leader>ghr", mode = { "n" }, function() require("gitsigns").reset_hunk() end, desc = "Reset Hunk" },
    { "<leader>ghs", mode = { "v" }, function() require("gitsigns").stage_hunk { vim.fn.line("."), vim.fn.line("v") } end, desc = "Stage Hunk (Visual)" },
    { "<leader>ghr", mode = { "v" }, function() require("gitsigns").reset_hunk { vim.fn.line("."), vim.fn.line("v") } end, desc = "Reset Hunk (Visual)" },
    { "<leader>ghS", mode = { "n" }, function() require("gitsigns").stage_buffer() end, desc = "Stage Buffer" },
    { "<leader>ghu", mode = { "n" }, function() require("gitsigns").undo_stage_hunk() end, desc = "Undo Stage Hunk" },
    { "<leader>ghR", mode = { "n" }, function() require("gitsigns").reset_buffer() end, desc = "Reset Buffer" },
    { "<leader>ghp", mode = { "n" }, function() require("gitsigns").preview_hunk() end, desc = "Preview Hunk" },
    { "<leader>ghb", mode = { "n" }, function() require("gitsigns").blame_line { full = true } end, desc = "Blame Line (Full)" },
    { "<leader>gtb", mode = { "n" }, function() require("gitsigns").toggle_current_line_blame() end, desc = "Toggle Current Line Blame" },
    { "<leader>ghd", mode = { "n" }, function() require("gitsigns").diffthis() end, desc = "Diff This" },
    { "<leader>ghD", mode = { "n" }, function() require("gitsigns").diffthis("~") end, desc = "Diff This (Against ~)" },
    { "<leader>gtd", mode = { "n" }, function() require("gitsigns").toggle_deleted() end, desc = "Toggle Deleted" },
		-- stylua: ignore end
	},
}
