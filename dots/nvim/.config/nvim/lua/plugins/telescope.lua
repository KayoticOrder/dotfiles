return {
	"nvim-telescope/telescope.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-telescope/telescope-frecency.nvim",
		"debugloop/telescope-undo.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
	},
	cmd = "Telescope",
	keys = function()
		local tb = require("telescope.builtin")
		local ts = require("telescope")
		local make_entry = require("telescope.make_entry")
		local entry_display = require("telescope.pickers.entry_display")

		local command_displayer = entry_display.create({
			separator = " ",
			items = {
				{ width = 24 },
				{ remaining = true },
			},
		})

		local function command_picker()
			local function format_command_description(entry)
				local description = entry.desc or entry.definition
				if description and description ~= "" then
					return description:gsub("\n", " ")
				end

				local details = {}
				if entry.complete and entry.complete ~= "" then
					table.insert(details, entry.complete == "<Lua function>" and "custom completion" or entry.complete)
				end
				if entry.nargs and entry.nargs ~= "" and entry.nargs ~= "0" then
					table.insert(details, string.format("args: %s", entry.nargs))
				end

				return #details > 0 and table.concat(details, " · ") or "No description"
			end

			tb.commands({
				entry_maker = function(entry)
					local description = format_command_description(entry)
					return make_entry.set_default_entry_mt({
						name = entry.name,
						description = description,
						value = entry,
						ordinal = string.format("%s %s", entry.name, description),
						display = function(item)
							return command_displayer({
								{ item.name, "TelescopeResultsIdentifier" },
								item.description,
							})
						end,
					}, {})
				end,
			})
		end

		return {
			{ "<leader>fz", tb.find_files, desc = "Fuzzy Files" },
			{ "<leader>ff", "<cmd>Telescope frecency workspace=CWD<cr>", desc = "Files" },
			{ "<leader>fg", tb.live_grep, desc = "Grep" },
			{ "<leader>fb", tb.buffers, desc = "Buffers" },
			{ "<leader>fc", command_picker, desc = "Commands" },
			{ "<leader>f:", tb.command_history, desc = "Command History" },
			{ "<leader>fh", tb.help_tags, desc = "Help Tags" },
			{ "<leader>fm", tb.keymaps, desc = "Keymaps" },
			{ "<leader>fs", tb.lsp_document_symbols, desc = "Symbols" },
			{ "<leader>fu", ts.extensions.undo.undo, desc = "Undo History" },
			{ "gd", tb.lsp_definitions, desc = "Definition" },
			{ "gD", tb.lsp_implementations, desc = "Implementation" },
			{ "gr", tb.lsp_references, desc = "References" },
		}
	end,
	config = function()
		local ts = require("telescope")
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")
		local ts_undo = require("telescope-undo.actions")
		local h_pct = 0.90
		local w_pct = 0.90
		local w_limit = 100
		local standard_setup = {
			borderchars = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
			preview = { hide_on_startup = true },
			layout_strategy = "horizontal",
			layout_config = {
				horizontal = {
					mirror = false,
					prompt_position = "top",
					width = function(_, cols, _)
						return math.min(math.floor(w_pct * cols), w_limit)
					end,
					height = function(_, _, rows)
						return math.floor(rows * h_pct)
					end,
					preview_cutoff = 10,
					preview_width = 0.65,
				},
			},
		}
		local fullscreen_setup = {
			borderchars = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
			preview = { hide_on_startup = false },
			layout_strategy = "flex",
			layout_config = {
				flex = { flip_columns = 100 },
				horizontal = {
					mirror = false,
					prompt_position = "top",
					width = function(_, cols, _)
						return math.floor(cols * w_pct)
					end,
					height = function(_, _, rows)
						return math.floor(rows * h_pct)
					end,
					preview_cutoff = 10,
					preview_width = 0.6,
				},
				vertical = {
					mirror = true,
					prompt_position = "top",
					width = function(_, cols, _)
						return math.floor(cols * w_pct)
					end,
					height = function(_, _, rows)
						return math.floor(rows * h_pct)
					end,
					preview_cutoff = 10,
					preview_height = 0.5,
				},
			},
		}
		local function delete_frecency_entry(prompt_bufnr)
			local current_picker = action_state.get_current_picker(prompt_bufnr)
			current_picker:delete_selection(function(selection)
				local path = selection.filename or selection.path or selection.value
				if path and path ~= "" then
					require("frecency").frecency:delete(path)
				end
			end)
		end
		ts.setup({
			defaults = vim.tbl_extend("error", standard_setup, {
				sorting_strategy = "ascending",
				path_display = { "filename_first" },
				mappings = {
					n = {
						["o"] = require("telescope.actions.layout").toggle_preview,
						["<C-c>"] = actions.close,
					},
					i = {
						["<C-o>"] = require("telescope.actions.layout").toggle_preview,
						["<C-j>"] = actions.move_selection_next,
						["<C-k>"] = actions.move_selection_previous,
						["<C-l>"] = actions.select_default,
						["<C-w>"] = actions.close,
					},
				},
			}),
			pickers = {
				buffers = {
					mappings = {
						i = { ["<C-d>"] = actions.delete_buffer },
						n = { ["dd"] = actions.delete_buffer },
					},
				},
				find_files = {
					find_command = {
						"fd",
						"--type",
						"f",
						"-H",
						"--strip-cwd-prefix",
					},
				},
			},
			extensions = {
				fzf = {
					fuzzy = true,
					override_generic_sorter = true,
					override_file_sorter = true,
					case_mode = "smart_case",
				},
				frecency = {
					prompt_title = "Find Files",
					workspace = "CWD",
					show_scores = false,
					show_unindexed = true,
					matcher = "fuzzy",
					show_filter_column = false,
					mappings = {
						i = {
							["<C-d>"] = delete_frecency_entry,
						},
						n = {
							["<C-d>"] = delete_frecency_entry,
						},
					},
				},
				undo = vim.tbl_extend("error", fullscreen_setup, {
					vim_diff_opts = { ctxlen = 4 },
					preview_title = "Diff",
					mappings = {
						i = {
							["<cr>"] = ts_undo.restore,
							["<C-cr>"] = ts_undo.restore,
							["<C-y>d"] = ts_undo.yank_deletions,
							["<C-y>a"] = ts_undo.yank_additions,
						},
						n = {
							["<cr>"] = ts_undo.restore,
							["ya"] = ts_undo.yank_additions,
							["yd"] = ts_undo.yank_deletions,
						},
					},
				}),
			},
		})
		ts.load_extension("fzf")
		ts.load_extension("undo")
		ts.load_extension("frecency")
	end,
}
