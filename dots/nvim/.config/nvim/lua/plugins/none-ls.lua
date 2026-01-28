return {
	"nvimtools/none-ls.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		local null_ls = require("null-ls")

		null_ls.setup({
			sources = {
				null_ls.builtins.formatting.cmake_format.with({
					command = "cmake-format", -- ensure it's in your PATH
				}),
			},
		})

		vim.api.nvim_create_autocmd("BufWritePre", {
			pattern = { "*.cmake", "CMakeLists.txt" },
			callback = function()
				vim.lsp.buf.format({
					timeout_ms = 2000,
					filter = function(client)
						return client.name == "null-ls"
					end,
				})
			end,
		})
	end,
}
