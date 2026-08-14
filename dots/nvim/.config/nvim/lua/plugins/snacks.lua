-- built by hand instead of the "telescope" preset, since that preset puts
-- the prompt below the results (reverse = true); this puts prompt on top.
-- shared so the explorer pops up centered like every other picker instead
-- of docked to a side.
local centered_layout = {
	reverse = false,
	layout = {
		box = "horizontal",
		backdrop = false,
		width = 0.9,
		height = 0.9,
		border = "none",
		{
			box = "vertical",
			{ win = "input", height = 1, border = true, title = "{title} {live} {flags}", title_pos = "center" },
			{ win = "list", title = " Results ", title_pos = "center", border = true },
		},
		{
			win = "preview",
			title = "{preview:Preview}",
			width = 0.55,
			border = true,
			title_pos = "center",
		},
	},
}

return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	-- snacks' own netrw-teardown races netrw's plugin/netrwPlugin.vim at startup
	-- and can lose; stop netrw from ever loading instead
	init = function()
		vim.g.loaded_netrw = 1
		vim.g.loaded_netrwPlugin = 1
	end,
	opts = {
		bigfile = { enabled = true },
		quickfile = { enabled = true },
		notifier = { enabled = true },
		indent = { enabled = true },
		words = { enabled = true },
		input = { enabled = true },
		gitbrowse = {},
		-- oil.nvim is gone; explorer now owns netrw replacement for directory buffers
		explorer = { replace_netrw = true },
		picker = {
			ui_select = true,
			layout = centered_layout,
			formatters = {
				file = { filename_first = true },
			},
			win = {
				list = {
					keys = { ["o"] = "toggle_preview" },
				},
			},
			sources = {
				-- explorer defaults to jump.close = false since it's normally a
				-- persistent sidebar; now that it's a centered modal, close it
				-- like every other picker when a file is opened
				explorer = { layout = centered_layout, jump = { close = true } },
			},
		},
	},
	keys = function()
		local function harpoon_picker()
			local harpoon = require("harpoon")
			local items = {}
			for _, item in ipairs(harpoon:list().items) do
				items[#items + 1] = { text = item.value, file = item.value }
			end
			require("snacks").picker.pick({
				source = "harpoon",
				title = "Harpoon Marks",
				items = items,
				format = "file",
			})
		end

		return {
			{
				"<leader>ff",
				function()
					require("snacks").picker.smart()
				end,
				desc = "Files (smart)",
			},
			{
				"<leader>fz",
				function()
					require("snacks").picker.files()
				end,
				desc = "Files (fuzzy)",
			},
			{
				"<leader>fg",
				function()
					require("snacks").picker.grep()
				end,
				desc = "Grep",
			},
			{
				"<leader>fb",
				function()
					require("snacks").picker.buffers()
				end,
				desc = "Buffers",
			},
			{
				"<leader>fc",
				function()
					require("snacks").picker.commands()
				end,
				desc = "Commands",
			},
			{
				"<leader>f:",
				function()
					require("snacks").picker.command_history()
				end,
				desc = "Command History",
			},
			{ "<leader>fh", harpoon_picker, desc = "Harpoon Marks" },
			{
				"<leader>ee",
				function()
					require("snacks").explorer()
				end,
				desc = "File Explorer",
			},
			{
				"<leader>fe",
				function()
					require("snacks").explorer()
				end,
				desc = "File Explorer",
			},
			{
				"<leader>f?",
				function()
					require("snacks").picker.help()
				end,
				desc = "Help Tags",
			},
			{
				"<leader>fm",
				function()
					require("snacks").picker.keymaps()
				end,
				desc = "Keymaps",
			},
			{
				"<leader>fs",
				function()
					require("snacks").picker.lsp_symbols()
				end,
				desc = "Symbols",
			},
			{
				"<leader>fS",
				function()
					require("snacks").picker.lsp_workspace_symbols()
				end,
				desc = "Workspace Symbols",
			},
			{
				"<leader>fw",
				function()
					require("snacks").picker.grep_word()
				end,
				mode = { "n", "x" },
				desc = "Grep Word/Selection",
			},
			{
				"<leader>fu",
				function()
					require("snacks").picker.undo()
				end,
				desc = "Undo History",
			},
			{
				"<leader>go",
				function()
					require("snacks").gitbrowse.open()
				end,
				desc = "Open in Browser",
			},
			{
				"<leader>un",
				function()
					require("snacks").notifier.show_history()
				end,
				desc = "Notification History",
			},
			{
				"]]",
				function()
					require("snacks").words.jump(vim.v.count1)
				end,
				desc = "Next Reference",
				mode = { "n", "t" },
			},
			{
				"[[",
				function()
					require("snacks").words.jump(-vim.v.count1)
				end,
				desc = "Prev Reference",
				mode = { "n", "t" },
			},
			{
				"gd",
				function()
					require("snacks").picker.lsp_definitions()
				end,
				desc = "Definition",
			},
			{
				"gD",
				function()
					require("snacks").picker.lsp_implementations()
				end,
				desc = "Implementation",
			},
			{
				"gr",
				function()
					require("snacks").picker.lsp_references()
				end,
				desc = "References",
			},
		}
	end,
}
