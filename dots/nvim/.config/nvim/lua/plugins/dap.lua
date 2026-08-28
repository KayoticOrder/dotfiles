return {
	{
		"mfussenegger/nvim-dap",
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
					require("dap").toggle_breakpoint()
				end,
				desc = "Toggle Breakpoint",
			},
			{
				"<leader>dB",
				function()
					require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
				end,
				desc = "Conditional Breakpoint",
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
				"<leader>dl",
				function()
					require("dap").run_last()
				end,
				desc = "Run Last",
			},
			{
				"<leader>dt",
				function()
					require("dap").terminate()
				end,
				desc = "Terminate",
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

			-- lldb-dap ships with the system LLVM/LLDB install (not via Mason), and
			-- distros disagree on the binary name: Arch ships it unversioned as
			-- `lldb-dap`, while Ubuntu versions it (e.g. `lldb-dap-18`). Resolve
			-- whichever is actually on PATH, falling back to the legacy
			-- `lldb-vscode` name used by older LLVM releases.
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

			dapui.setup()
			require("nvim-dap-virtual-text").setup()

			dap.listeners.after.event_initialized["dapui_config"] = function()
				dapui.open()
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close()
			end

			vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
			vim.fn.sign_define("DapBreakpointCondition", { text = "●", texthl = "DiagnosticWarn" })
			vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticInfo", linehl = "DapStoppedLine" })
			vim.fn.sign_define("DapLogPoint", { text = "◆", texthl = "DiagnosticInfo" })

			dap.configurations.cpp = {
				{
					name = "Launch",
					type = "lldb",
					request = "launch",
					program = function()
						return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
					end,
					cwd = "${workspaceFolder}",
					stopOnEntry = false,
					args = function()
						return vim.split(vim.fn.input("Program args: "), " ", { trimempty = true })
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
}
