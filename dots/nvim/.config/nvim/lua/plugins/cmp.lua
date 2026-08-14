-- replaced by blink.cmp + blink-cmp-copilot, see plugins/blink.lua
return {
	{
		"zbirenbaum/copilot-cmp",
		enabled = false,
		config = function()
			require("copilot_cmp").setup()
		end,
	},
	{
		"hrsh7th/nvim-cmp",
		enabled = false,
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

			local fuzzy_matching = {
				disallow_fuzzy_matching = false,
				disallow_fullfuzzy_matching = false,
				disallow_partial_fuzzy_matching = false,
				disallow_partial_matching = false,
				disallow_prefix_unmatching = false,
				disallow_symbol_nonprefix_matching = false,
			}

			local function select_next(fallback)
				if cmp.visible() then
					cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
				else
					fallback()
				end
			end

			local function select_prev(fallback)
				if cmp.visible() then
					cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
				else
					fallback()
				end
			end

			local function confirm_selection(fallback)
				if cmp.visible() then
					cmp.confirm({ select = true })
				else
					fallback()
				end
			end

			local function close_completion(fallback)
				if cmp.visible() then
					cmp.close()
				else
					fallback()
				end
			end

			local cmdline_mapping = cmp.mapping.preset.cmdline({
				["<C-j>"] = { c = select_prev },
				["<C-k>"] = { c = select_next },
				["<C-h>"] = { c = close_completion },
				["<C-l>"] = { c = confirm_selection },
				["<C-f>"] = { c = confirm_selection },
				["<C-CR>"] = { c = confirm_selection },
			})

			cmp.setup.cmdline({ "/", "?" }, {
				mapping = cmdline_mapping,
				matching = fuzzy_matching,
				sources = {
					{ name = "buffer" },
				},
			})

			cmp.setup.cmdline(":", {
				mapping = cmdline_mapping,
				matching = fuzzy_matching,
				sources = cmp.config.sources({
					{ name = "path" },
				}, {
					{
						name = "cmdline",
						option = {
							ignore_cmds = { "Man", "!" },
						},
						matching = fuzzy_matching,
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
					entries = {
						name = "custom",
						selection_order = "near_cursor",
					},
				},
				preselect = auto_select and cmp.PreselectMode.Item or cmp.PreselectMode.None,
				mapping = cmp.mapping.preset.insert({
					["<C-f>"] = cmp.mapping.confirm({ select = true }),
					["<C-Space>"] = cmp.mapping.complete(),
					["<C-e>"] = cmp.mapping.close(),
					["<C-j>"] = cmp.mapping.select_prev_item(),
					["<C-k>"] = cmp.mapping.select_next_item(),
					["<C-l>"] = cmp.mapping.confirm({ select = true }),
					["<C-CR>"] = cmp.mapping.confirm({ select = true }),
					["<CR>"] = cmp.mapping.disable,
				}),
				sources = {
					{ name = "copilot", group_index = 2 },
					{ name = "nvim_lsp", group_index = 2 },
					{ name = "buffer", group_index = 2 },
					{ name = "path", group_index = 2 },
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
