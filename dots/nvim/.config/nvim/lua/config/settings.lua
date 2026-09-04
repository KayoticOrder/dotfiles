local opt = vim.opt

vim.cmd("colorscheme kanagawa-wave")

-- dap.lua's DapStopped sign uses this linehl; must be set after the
-- colorscheme so `hi clear` on load doesn't wipe it
vim.api.nvim_set_hl(0, "DapStoppedLine", { link = "Visual" })

opt.clipboard = vim.env.SSH_TTY and "" or "unnamedplus" -- Sync with system clipboard
opt.expandtab = true -- Use spaces instead of tabs
opt.shiftwidth = 2 -- Number of spaces for each indentation level
opt.tabstop = 2 -- Number of spaces that a <Tab> represents
opt.softtabstop = 2 -- Number of spaces for a Tab when editing
opt.wrap = false
opt.conceallevel = 2 -- Required for obsidian.nvim UI features (link concealing, checkboxes, etc.)

opt.list = true -- Show invisible characters
opt.listchars:append({
	tab = "▏ ",
})
opt.wildmenu = true
opt.wildmode = "longest:full,full"
opt.wildoptions = "pum,fuzzy"
opt.wildignorecase = true
opt.pumheight = 12

opt.number = true
opt.relativenumber = true
opt.cursorline = true

opt.undofile = true
opt.undodir = vim.fn.expand("~/.vim/undo")

opt.exrc = true -- Allow project-specific .nvimrc files
opt.secure = true -- Disable potentially unsafe commands in local .nvimrc files

opt.autoread = true
vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorHoldI", "FocusGained" }, {
	command = "if mode() != 'c' | checktime | endif",
	pattern = { "*" },
})

opt.textwidth = 80

vim.o.termguicolors = true
vim.o.signcolumn = "yes"
vim.o.winborder = "single" -- default border for floats that don't set their own
vim.diagnostic.config({
	signs = true,
	virtual_text = false,
	underline = true,
})

-- Disable automatic comment continuation on new lines with 'o'
vim.api.nvim_create_autocmd("BufEnter", {
	callback = function()
		vim.opt.formatoptions:remove({ "o" })
	end,
})

-- vim.ui.open() (used by the built-in `gx`) tries xdg-open before wslview,
-- and xdg-open doesn't have a working browser handler under WSL; force it
-- to hand off to Windows instead
if vim.fn.has("wsl") == 1 then
	local wsl_open_cmd = (vim.fn.executable("wslview") == 1 and { "wslview" })
		or (vim.fn.executable("explorer.exe") == 1 and { "explorer.exe" })
	if wsl_open_cmd then
		local ui_open = vim.ui.open
		vim.ui.open = function(path, opts)
			opts = opts or {}
			opts.cmd = opts.cmd or wsl_open_cmd
			return ui_open(path, opts)
		end
	end
end
