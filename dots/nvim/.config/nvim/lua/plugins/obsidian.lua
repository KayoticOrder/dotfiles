return {
	"obsidian-nvim/obsidian.nvim",
	version = "*", -- use latest release, remove to use latest commit
	ft = "markdown",
	dependencies = { "nvim-lua/plenary.nvim" },
	---@module 'obsidian'
	---@type obsidian.config
	opts = {
		legacy_commands = false, -- this will be removed in the next major release
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
		callbacks = {
			enter_note = function(client, note)
				local map = function(key, cmd, desc)
					vim.keymap.set("n", key, cmd, { buffer = true, desc = desc })
				end

				-- Notes
				map("<leader>on", "<cmd>Obsidian new<cr>", "Obsidian: New note")
				map("<leader>oo", "<cmd>Obsidian quick_switch<cr>", "Obsidian: Quick switch")
				map("<leader>og", "<cmd>Obsidian search<cr>", "Obsidian: Grep notes")
				map("<leader>ot", "<cmd>Obsidian tags<cr>", "Obsidian: Browse tags")
				map("<leader>or", "<cmd>Obsidian rename<cr>", "Obsidian: Rename note")

				-- Daily notes
				map("<leader>od", "<cmd>Obsidian today<cr>", "Obsidian: Today's note")
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
