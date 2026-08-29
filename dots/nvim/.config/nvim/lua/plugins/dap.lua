return {
	{
		"mfussenegger/nvim-dap",
		-- init always runs at startup; config is deferred until the first
		-- <leader>d* press, too late for persistent-breakpoints' BufReadPost
		-- restore to have sign types to place.
		init = function()
			vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
			vim.fn.sign_define("DapBreakpointCondition", { text = "●", texthl = "DiagnosticWarn" })
			vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticInfo", linehl = "DapStoppedLine" })
			vim.fn.sign_define("DapLogPoint", { text = "◆", texthl = "DiagnosticInfo" })
			-- shown when the adapter rejects a breakpoint (verified=false), e.g. a stale binary
			vim.fn.sign_define("DapBreakpointRejected", { text = "○", texthl = "DiagnosticHint" })
		end,
		dependencies = {
			"rcarriga/nvim-dap-ui",
			"nvim-neotest/nvim-nio",
			"theHamsta/nvim-dap-virtual-text",
			{
				"jay-babu/mason-nvim-dap.nvim",
				dependencies = "williamboman/mason.nvim",
				opts = {
					ensure_installed = {},
					automatic_installation = true,
					handlers = {},
				},
			},
		},
		keys = {
			{
				"<leader>db",
				function()
					require("persistent-breakpoints.api").toggle_breakpoint()
				end,
				desc = "Toggle Breakpoint",
			},
			{
				"<leader>dB",
				function()
					require("persistent-breakpoints.api").set_conditional_breakpoint()
				end,
				desc = "Conditional Breakpoint",
			},
			{
				"<leader>dC",
				function()
					require("persistent-breakpoints.api").clear_all_breakpoints()
				end,
				desc = "Clear Breakpoints",
			},
			{
				"<leader>dc",
				function()
					require("dap").continue()
				end,
				desc = "Continue",
			},
			{
				"<leader>di",
				function()
					require("dap").step_into()
				end,
				desc = "Step Into",
			},
			{
				"<leader>do",
				function()
					require("dap").step_over()
				end,
				desc = "Step Over",
			},
			{
				"<leader>dO",
				function()
					require("dap").step_out()
				end,
				desc = "Step Out",
			},
			{
				"<leader>dk",
				function()
					require("dap").up()
				end,
				desc = "Up Stack Frame",
			},
			{
				"<leader>dj",
				function()
					require("dap").down()
				end,
				desc = "Down Stack Frame",
			},
			{
				"<leader>dr",
				function()
					require("dap").repl.toggle()
				end,
				desc = "Toggle REPL",
			},
			{
				"<leader>dt",
				function()
					require("dap").terminate()
				end,
				desc = "Terminate",
			},
			{
				"<leader>dh",
				function()
					-- default "hover" context isn't expandable on lldb-dap; "repl" is
					require("dapui").eval(nil, { context = "repl" })
				end,
				mode = { "n", "v" },
				desc = "Hover",
			},
			{
				"<leader>du",
				function()
					require("dapui").toggle()
				end,
				desc = "Toggle DAP UI",
			},
		},
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")

			-- dap.ui.widgets floats enter focus but don't bind a close key
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "dap-float",
				callback = function(args)
					vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = args.buf, silent = true })
				end,
			})

			-- distros disagree on the lldb-dap binary name (e.g. Arch: `lldb-dap`,
			-- Ubuntu: `lldb-dap-18`); fall back to the old `lldb-vscode` name too
			local function find_lldb_dap()
				if vim.fn.executable("lldb-dap") == 1 then
					return "lldb-dap"
				end

				for _, dir in ipairs(vim.split(vim.env.PATH or "", ":")) do
					local matches = vim.fn.glob(dir .. "/lldb-dap-*", false, true)
					if #matches > 0 then
						table.sort(matches)
						return matches[#matches]
					end
				end

				if vim.fn.executable("lldb-vscode") == 1 then
					return "lldb-vscode"
				end

				return "lldb-dap"
			end

			dap.adapters.lldb = {
				type = "executable",
				command = find_lldb_dap(),
				name = "lldb",
			}

			-- match the box-drawing border already used for telescope/snacks floats
			local dapui_border = { "┏", "━", "┓", "┃", "┛", "━", "┗", "┃" }

			dapui.setup({
				icons = { expanded = "▾", collapsed = "▸", current_frame = "▶" },
				floating = {
					border = dapui_border,
					mappings = { close = { "q", "<Esc>" } },
				},
				render = {
					max_value_lines = 100,
				},
				layouts = {
					{
						elements = {
							{ id = "scopes", size = 0.4 },
							{ id = "breakpoints", size = 0.2 },
							{ id = "stacks", size = 0.2 },
							{ id = "watches", size = 0.2 },
						},
						size = 50,
						position = "left",
					},
					{
						elements = {
							{ id = "repl", size = 0.6 },
							{ id = "console", size = 0.4 },
						},
						size = 12,
						position = "bottom",
					},
				},
			})
			require("nvim-dap-virtual-text").setup({
				all_frames = true,
			})

			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close()
			end

			-- program/args are functions dap resolves via pairs() (unordered), so
			-- a shared cache keeps prompt order fixed; last_program/last_args
			-- persist across launches so re-prompts pre-fill instead of blank.
			local last_program = vim.fn.getcwd() .. "/"
			local last_args = ""
			local launch_inputs_cache
			local function resolve_launch_inputs()
				if not launch_inputs_cache then
					last_program = vim.fn.input("Path to executable: ", last_program, "file")
					last_args = vim.fn.input("Program args: ", last_args)
					launch_inputs_cache = {
						program = last_program,
						args = vim.split(last_args, " ", { trimempty = true }),
					}
				end
				return launch_inputs_cache
			end
			dap.listeners.after.event_initialized["launch_inputs_reset"] = function()
				launch_inputs_cache = nil
			end

			dap.configurations.cpp = {
				{
					name = "Launch",
					type = "lldb",
					request = "launch",
					program = function()
						return resolve_launch_inputs().program
					end,
					cwd = "${workspaceFolder}",
					stopOnEntry = false,
					args = function()
						return resolve_launch_inputs().args
					end,
				},
				{
					name = "Attach to process",
					type = "lldb",
					request = "attach",
					pid = require("dap.utils").pick_process,
					cwd = "${workspaceFolder}",
				},
			}
			dap.configurations.c = dap.configurations.cpp
		end,
	},
	{
		"Weissle/persistent-breakpoints.nvim",
		-- own top-level plugin so restore doesn't wait on nvim-dap's lazy-load
		event = "BufReadPost",
		opts = {
			load_breakpoints_event = { "BufReadPost" },
		},
	},
}
