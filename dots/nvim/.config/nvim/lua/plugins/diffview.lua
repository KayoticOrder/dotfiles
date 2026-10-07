-- Diffview picks the repo from the current buffer's file, not the cwd, so a
-- buffer from another repo (or a symlinked config) hijacks the view; -C pins
-- it to the cwd's repo.
local function diffview(cmd, args)
	vim.cmd(cmd .. " " .. args .. " -C=" .. vim.fn.fnameescape(vim.fn.getcwd()))
end

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
		{
			"<leader>gd",
			function()
				diffview("DiffviewOpen", "")
			end,
			desc = "Diff View Open",
		},
		{ "<leader>gD", "<cmd>DiffviewClose<cr>", desc = "Diff View Close" },
		{
			"<leader>gH",
			function()
				diffview("DiffviewFileHistory", "")
			end,
			desc = "File History",
		},
		{
			"<leader>gc",
			function()
				pick_commit("Diff Against Commit", function(commit)
					diffview("DiffviewOpen", commit)
				end)
			end,
			desc = "Diff Working Tree Against Commit",
		},
		{
			"<leader>gC",
			function()
				pick_commit("Show Commit", function(commit)
					diffview("DiffviewOpen", commit .. "^!")
				end)
			end,
			desc = "Show Commit Diff",
		},
	},
}
