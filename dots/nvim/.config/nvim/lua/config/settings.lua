local opt = vim.opt

vim.cmd("colorscheme kanagawa")

opt.clipboard = vim.env.SSH_TTY and "" or "unnamedplus" -- Sync with system clipboard
opt.expandtab = true -- Use spaces instead of tabs
opt.shiftwidth = 2 -- Number of spaces for each indentation level
opt.tabstop = 2 -- Number of spaces that a <Tab> represents
opt.softtabstop = 2 -- Number of spaces for a Tab when editing
opt.wrap = false

opt.list = true -- Show invisible characters
opt.listchars:append({
	tab = "▏ ",
})

opt.number = true
opt.relativenumber = false
opt.cursorline = true

opt.undofile = true
opt.undodir = vim.fn.expand("~/.vim/undo")

opt.exrc = true -- Allow project-specific .nvimrc files
opt.secure = true -- Disable potentially unsafe commands in local .nvimrc files

vim.o.signcolumn = "yes"
vim.diagnostic.config({
	signs = true,
	virtual_text = false,
	underline = true,
})
