return {
	"obsidian-nvim/obsidian.nvim",
	version = "*", -- use latest release, remove to use latest commit
	ft = "markdown",
	dependencies = { "nvim-lua/plenary.nvim" },
	-- Global entry points: work from any buffer/project, not just inside a note.
	-- `keys` also lazy-loads the plugin on first press even without a markdown buffer open.
	keys = {
		{ "<leader>on", "<cmd>Obsidian new<cr>", desc = "Obsidian: New note" },
		{ "<leader>od", "<cmd>Obsidian today<cr>", desc = "Obsidian: Today's note" },
		{ "<leader>oo", "<cmd>Obsidian quick_switch<cr>", desc = "Obsidian: Quick switch" },
		{ "<leader>og", "<cmd>Obsidian search<cr>", desc = "Obsidian: Grep notes" },
		{ "<leader>ot", "<cmd>Obsidian new todo<cr>", desc = "Obsidian: Todo list" },
	},
	---@module 'obsidian'
	---@type obsidian.config
	opts = {
		legacy_commands = false, -- this will be removed in the next major release
		ui = {
			enable = false, -- render-markdown.nvim handles conceal-based rendering instead
		},
		workspaces = {
			{
				name = "personal",
				path = "~/vaults/personal",
			},
			{
				name = "work",
				path = "~/vaults/work",
			},
		},
		note_id_func = function(title)
			if title ~= nil then
				-- If title is given, use it as the filename.
				-- You can optionally add string replacements here to sanitize it if needed.
				return title
			else
				-- If title is nil, just generate a random timestamp/ID.
				return tostring(os.time())
			end
		end,
		callbacks = {
			enter_note = function(client, note)
				local map = function(key, cmd, desc)
					vim.keymap.set("n", key, cmd, { buffer = true, desc = desc })
				end

				-- Notes
				map("<leader>oz", "<cmd>Obsidian tags<cr>", "Obsidian: Browse tags")
				map("<leader>or", "<cmd>Obsidian rename<cr>", "Obsidian: Rename note")

				-- Daily notes
				map("<leader>oD", "<cmd>Obsidian yesterday<cr>", "Obsidian: Yesterday's note")
				map("<leader>om", "<cmd>Obsidian tomorrow<cr>", "Obsidian: Tomorrow's note")

				-- Links
				map("<leader>ol", "<cmd>Obsidian links<cr>", "Obsidian: List links")
				map("<leader>ob", "<cmd>Obsidian backlinks<cr>", "Obsidian: Backlinks")
				map("<leader>oL", "<cmd>Obsidian link_new<cr>", "Obsidian: Link new note")
				map("gf", "<cmd>Obsidian follow_link<cr>", "Obsidian: Follow link")

				-- Templates & misc
				map("<leader>op", "<cmd>Obsidian template<cr>", "Obsidian: Insert template")
				map("<leader>oT", "<cmd>Obsidian toc<cr>", "Obsidian: Table of contents")
				map("<leader>ox", "<cmd>Obsidian toggle_checkbox<cr>", "Obsidian: Toggle checkbox")
				map("<leader>ow", "<cmd>Obsidian workspace<cr>", "Obsidian: Switch workspace")
				map("<leader>oO", "<cmd>Obsidian open<cr>", "Obsidian: Open in app")
			end,
		},
	},
}
