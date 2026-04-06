return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	keys = function()
		local harpoon = require("harpoon")
		local keys = {
			{
				"<leader>ha",
				function()
					harpoon:list():add()
				end,
				desc = "Add File",
			},
			{
				"<leader>hh",
				function()
					harpoon.ui:toggle_quick_menu(harpoon:list())
				end,
				desc = "Menu",
			},
			{
				"]h",
				function()
					harpoon:list():next()
				end,
				desc = "Next Harpoon File",
			},
			{
				"[h",
				function()
					harpoon:list():prev()
				end,
				desc = "Prev Harpoon File",
			},
		}

		for i = 1, 5 do
			keys[#keys + 1] = {
				string.format("<leader>%d", i),
				function()
					harpoon:list():select(i)
				end,
				desc = string.format("Harpoon File %d", i),
			}

			keys[#keys + 1] = {
				string.format("<leader>h%d", i),
				function()
					harpoon:list():replace_at(i)
				end,
				desc = string.format("Assign File to Slot %d", i),
			}
		end

		return keys
	end,
	config = function()
		local harpoon = require("harpoon")
		local ok_extensions, extensions = pcall(require, "harpoon.extensions")

		local function harpoon_key()
			local cwd = vim.loop.cwd()
			local git_root = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })[1]

			if vim.v.shell_error ~= 0 or not git_root or git_root == "" then
				return cwd
			end

			local branch = vim.fn.systemlist({ "git", "branch", "--show-current" })[1]
			if vim.v.shell_error ~= 0 or not branch or branch == "" then
				return git_root
			end

			return string.format("%s::%s", git_root, branch)
		end

		harpoon:setup({
			settings = {
				save_on_toggle = true,
				sync_on_ui_close = true,
				key = harpoon_key,
			},
		})

		if ok_extensions and type(harpoon.extend) == "function" then
			harpoon:extend(extensions.builtins.highlight_current_file())
			harpoon:extend({
				UI_CREATE = function(cx)
					vim.keymap.set("n", "<C-v>", function()
						harpoon.ui:select_menu_item({ vsplit = true })
					end, { buffer = cx.bufnr, desc = "Open in vertical split" })

					vim.keymap.set("n", "<C-x>", function()
						harpoon.ui:select_menu_item({ split = true })
					end, { buffer = cx.bufnr, desc = "Open in horizontal split" })

					vim.keymap.set("n", "<C-t>", function()
						harpoon.ui:select_menu_item({ tabedit = true })
					end, { buffer = cx.bufnr, desc = "Open in new tab" })
				end,
			})
		end
	end,
}
