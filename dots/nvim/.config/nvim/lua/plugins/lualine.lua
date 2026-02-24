return {
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = {
			options = {
				icons_enabled = true,
				theme = "auto",
				component_separators = { left = "", right = "" },
				section_separators = { left = "", right = "" },
				disabled_filetypes = {
					statusline = {},
					winbar = {},
				},
				ignore_focus = {},
				always_divide_middle = true,
				always_show_tabline = true,
				globalstatus = false,
				refresh = {
					statusline = 100,
					tabline = 100,
					winbar = 100,
				},
			},
			sections = {
				lualine_a = { "mode" },
				lualine_b = { "branch", "diff", "diagnostics" },
				lualine_c = { "filename" },
				lualine_x = {
					{
						function()
							local icons = {
								[""] = " ",
								["Normal"] = " ",
								["InProgress"] = " ",
								["Warning"] = " ",
							}
							local ok, api = pcall(require, "copilot.api")
							if not ok then return "" end
							local status = api.status.data.status or ""
							return icons[status] or " "
						end,
						color = function()
							local ok, api = pcall(require, "copilot.api")
							if not ok then return {} end
							local status = api.status.data.status or ""
							return status == "Warning" and { fg = "#e5c07b" }
								or status == "InProgress" and { fg = "#61afef" }
								or status == "Normal" and { fg = "#98c379" }
								or { fg = "#636363" }
						end,
					},
					"encoding",
					"fileformat",
					"filetype",
				},
				lualine_y = { "progress" },
				lualine_z = { "location" },
			},
			inactive_sections = {
				lualine_a = {},
				lualine_b = {},
				lualine_c = { "filename" },
				lualine_x = { "location" },
				lualine_y = {},
				lualine_z = {},
			},
			tabline = {},
			winbar = {},
			inactive_winbar = {},
			extensions = {},
		},
	},
}
