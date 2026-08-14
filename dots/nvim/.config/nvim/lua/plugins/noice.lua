return {
	"folke/noice.nvim",
	event = "VeryLazy",
	dependencies = {
		"MunifTanjim/nui.nvim",
	},
	opts = {
		lsp = {
			override = {
				["vim.lsp.util.convert_input_to_markdown_lines"] = true,
				["vim.lsp.util.stylize_markdown"] = true,
			},
		},
		presets = {
			bottom_search = true,
			command_palette = true,
			long_message_to_split = true,
			inc_rename = false,
			lsp_doc_border = false,
		},
		-- blink.cmp (plugins/blink.lua) handles cmdline completion itself now,
		-- and auto-detects noice for cmdline ghost text; nothing to wire up here
		-- snacks.notifier already owns vim.notify (see plugins/snacks.lua); don't
		-- let noice fight it for that hook, same lesson as the netrw hand-off
		notify = { enabled = false },
	},
}
