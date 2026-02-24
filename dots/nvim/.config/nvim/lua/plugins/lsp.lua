return {
	{
		"nvimdev/lspsaga.nvim",
		lazy = false,
		keys = {
			{ "<leader>ci", ":Lspsaga hover_doc<CR>", desc = "Hover Info" },
			{ "<leader>cr", ":Lspsaga rename<CR>", desc = "Rename Symbol" },
		},
		opts = {
			ui = {
				code_action = "",
			},
		},
	},
	{
		"williamboman/mason.nvim",
		cmd = "Mason",
		keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
		build = ":MasonUpdate",
		opts_extend = { "ensure_installed" },
		opts = {
			ensure_installed = {
				"stylua",
				"shfmt",
			},
		},
		config = function(_, opts)
			require("mason").setup(opts)
			local mr = require("mason-registry")
			mr:on("package:install:success", function()
				vim.defer_fn(function()
					-- trigger FileType event to possibly load this newly installed LSP server
					require("lazy.core.handler.event").trigger({
						event = "FileType",
						buf = vim.api.nvim_get_current_buf(),
					})
				end, 100)
			end)

			mr.refresh(function()
				for _, tool in ipairs(opts.ensure_installed) do
					local p = mr.get_package(tool)
					if not p:is_installed() then
						p:install()
					end
				end
			end)
		end,
	},

	{
		"williamboman/mason-lspconfig.nvim",
		config = function()
			require("mason-lspconfig").setup({
				handlers = {
					-- The first entry (without a key) will be the default handler
					function(server_name)
						require("lspconfig")[server_name].setup({})
					end,
					["lua_ls"] = function()
						require("lspconfig").lua_ls.setup({
							on_init = function(client)
								if client.workspace_folders then
									local path = client.workspace_folders[1].name
									if
										vim.uv.fs_stat(path .. "/.uarc.json")
										or vim.uv.fs_stat(path .. "/.luarc.jsonc")
									then
										return
									end
								end

								client.config.settings.Lua =
									vim.tbl_deep_extend("force", client.config.settings.Lua, {
										runtime = {
											version = "LuaJIT",
										},
										workspace = {
											checkThirdParty = false,
											library = {
												vim.env.VIMRUNTIME,
											},
										},
									})
							end,
							settings = {
								Lua = {
									diagnostics = {
										globals = { "vim" },
									},
								},
							},
						})
					end,
				},
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		keys = {
			{
				"<M-o>",
				"<cmd>ClangdSwitchSourceHeader<cr>",
				desc = "Clangd Switch Source Header",
				ft = { "h", "hpp", "c", "cpp" },
			},
		},
	},
}
