-- Set up window navigation mappings
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Move to bottom window" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Move to top window" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })
vim.keymap.set("v", "*", [[y/\V<C-r>=escape(@",'/\')<CR><CR>]], {
	noremap = true,
	silent = true,
	desc = "Search for selected text",
})

vim.keymap.set("n", "<leader>cd", function()
	vim.diagnostic.open_float(nil, {
		focusable = false,
	})
end, { noremap = true, silent = true, desc = "Diagnostics" })

-- Move by visual (wrapped) line instead of file line; a no-op when wrap is
-- off, since gj/gk == j/k there. v:count check keeps counts (e.g. 5j) exact.
vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- "+" so it reaches the system clipboard even over SSH (clipboard is "" there,
-- see settings.lua), where nvim falls back to OSC 52
local function yank_path(modifier, with_line)
	return function()
		local path = vim.fn.expand("%" .. modifier)
		if path == "" then
			return vim.notify("Buffer has no file", vim.log.levels.WARN)
		end
		if with_line then
			path = path .. ":" .. vim.fn.line(".")
		end
		vim.fn.setreg("+", path)
		vim.fn.setreg('"', path)
		vim.notify("Copied " .. path)
	end
end
vim.keymap.set("n", "<leader>yp", yank_path(":."), { desc = "Copy relative path" })
vim.keymap.set("n", "<leader>yP", yank_path(":p"), { desc = "Copy absolute path" })
vim.keymap.set("n", "<leader>yl", yank_path(":.", true), { desc = "Copy relative path:line" })
vim.keymap.set("n", "<leader>yn", yank_path(":t"), { desc = "Copy file name" })
