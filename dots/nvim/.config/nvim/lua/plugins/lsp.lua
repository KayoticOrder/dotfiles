return {
	{
		"nvimdev/lspsaga.nvim",
		lazy = false,
		keys = {
			{ "<leader>ci", ":Lspsaga hover_doc<CR>", desc = "Hover Info" },
			{ "<leader>cr", ":Lspsaga rename<CR>", desc = "Rename Symbol" },
			{ "<leader>ck", ":Lspsaga incoming_calls<CR>", desc = "Incoming Calls" },
			{ "<leader>co", ":Lspsaga outgoing_calls<CR>", desc = "Outgoing Calls" },
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
		dependencies = {
			"neovim/nvim-lspconfig",
		},
		config = function()
			require("mason-lspconfig").setup()

			vim.lsp.config("lua_ls", {
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
	{
		"neovim/nvim-lspconfig",
		keys = {
			{
				"<M-o>",
				"<cmd>LspClangdSwitchSourceHeader<cr>",
				desc = "Clangd Switch Source Header",
				ft = { "h", "hpp", "c", "cpp" },
			},
		},
	},
}
