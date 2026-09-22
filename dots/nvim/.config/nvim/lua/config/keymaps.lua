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
