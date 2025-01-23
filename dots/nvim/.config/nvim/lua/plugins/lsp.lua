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
			require("mason-lspconfig").setup()
			require("mason-lspconfig").setup_handlers({
				-- The first entry (without a key) will be the default handler
				-- and will be called for each installed server that doesn't have
				-- a dedicated handler.
				function(server_name) -- default handler (optional)
					require("lspconfig")[server_name].setup({})
				end,
				-- Next, you can provide a dedicated handler for specific servers.
				-- For example, a handler override for the `rust_analyzer`:
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
										-- Tell the language server which version of Lua you're using
										-- (most likely LuaJIT in the case of Neovim)
										version = "LuaJIT",
									},
									-- Make the server aware of Neovim runtime files
									workspace = {
										checkThirdParty = false,
										library = {
											vim.env.VIMRUNTIME,
											-- Depending on the usage, you might want to add additional paths here.
											-- "${3rd}/luv/library"
											-- "${3rd}/busted/library",
										},
										-- or pull in all of 'runtimepath'. NOTE: this is a lot slower and will cause issues when working on your own configuration (see https://github.com/neovim/nvim-lspconfig/issues/3191)
										-- library = vim.api.nvim_get_runtime_file("", true)
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
