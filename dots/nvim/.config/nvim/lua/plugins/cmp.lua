return {
	{
		"zbirenbaum/copilot-cmp",
		config = function()
			require("copilot_cmp").setup()
		end,
	},
	{
		"hrsh7th/nvim-cmp",
		lazy = false,
		version = false, -- last release is way too old
		event = "InsertEnter",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-path",
			"hrsh7th/cmp-cmdline",
			"zbirenbaum/copilot-cmp",
		},
		config = function()
			local cmp = require("cmp")
			local auto_select = true
			require("copilot_cmp").setup()

			cmp.setup.cmdline(":", {
				sources = cmp.config.sources({
					{ name = "path" },
				}, {
					{
						name = "cmdline",
						option = {
							ignore_cmds = { "Man", "!" },
						},
					},
				}),
			})

			cmp.setup({
				auto_brackets = {},
				performance = {
					max_view_entries = 10,
				},
				completion = {
					completeopt = "menu,menuone,noinsert" .. (auto_select and "" or ",noselect"),
				},
				view = {
					entries = "custom",
				},
				preselect = auto_select and cmp.PreselectMode.Item or cmp.PreselectMode.None,
				mapping = cmp.mapping.preset.insert({
					["<C-f>"] = cmp.mapping.confirm(),
					["<C-Space>"] = cmp.mapping.complete(),
					["<C-e>"] = cmp.mapping.close(),
					["<C-j>"] = cmp.mapping.select_next_item(),
					["<C-k>"] = cmp.mapping.select_prev_item(),
					["<CR>"] = cmp.mapping.disable,
				}),
				sources = {
					{ name = "copilot", group_index = 2 },
					{ name = "nvim_lsp", group_index = 2 },
					{ name = "buffer", group_index = 2 },
					{ name = "path", group_index = 2 },
					{ name = "cmdline", group_index = 2 },
				},
				experimental = {
					-- only show ghost text when we show ai completions
					ghost_text = true,
				},
				window = {
					completion = cmp.config.window.bordered(),
					documentation = cmp.config.window.bordered(),
				},
			})
		end,
	},
}
