-- snacks' git_log defaults to checking out the picked commit on <cr>, so
-- the confirm action is always overridden here
local function pick_commit(title, on_pick)
	require("snacks").picker.git_log({
		title = title,
		confirm = function(picker, item)
			picker:close()
			if item then
				on_pick(item.commit)
			end
		end,
	})
end

return {
	-- sindrets/diffview.nvim is unmaintained since mid-2024; this fork has
	-- ongoing bug fixes and is API-compatible (same commands/keymaps)
	"dlyongemallo/diffview.nvim",
	cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
	keys = {
		{ "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff View Open" },
		{ "<leader>gD", "<cmd>DiffviewClose<cr>", desc = "Diff View Close" },
		{ "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "File History" },
		{
			"<leader>gc",
			function()
				pick_commit("Diff Against Commit", function(commit)
					vim.cmd("DiffviewOpen " .. commit)
				end)
			end,
			desc = "Diff Working Tree Against Commit",
		},
		{
			"<leader>gC",
			function()
				pick_commit("Show Commit", function(commit)
					vim.cmd("DiffviewOpen " .. commit .. "^!")
				end)
			end,
			desc = "Show Commit Diff",
		},
	},
}
