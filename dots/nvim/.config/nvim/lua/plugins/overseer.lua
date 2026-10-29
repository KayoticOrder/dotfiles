-- Per-repo build definitions live in an untracked .nvim-build.lua at the repo root
-- (see the example at the bottom of this file).
local spec_file = ".nvim-build.lua"
local rbuild = vim.fn.expand("~/.local/bin/rbuild")

local function load_spec(root)
	local path = vim.fs.joinpath(root, spec_file)
	-- Prompts once per file (and again whenever it changes), like 'exrc'.
	local src = vim.secure.read(path)
	if not src then
		return nil, path .. " is not trusted"
	end
	local chunk, err = load(src, "@" .. path)
	if not chunk then
		return nil, err
	end
	local ok, spec = pcall(chunk)
	if not ok then
		return nil, spec
	end
	return spec
end

local function rbuild_cmd(spec, cmd)
	local ret = { rbuild }
	if spec.host then
		vim.list_extend(ret, { "-H", spec.host })
	end
	if spec.remote_dir then
		vim.list_extend(ret, { "-d", spec.remote_dir })
	end
	for _, dir in ipairs(spec.artifacts or {}) do
		vim.list_extend(ret, { "-a", dir })
	end
	table.insert(ret, "--")
	return vim.list_extend(ret, cmd)
end

local provider = {
	name = "remote builds",
	cache_key = function(opts)
		return vim.fs.find(spec_file, { upward = true, type = "file", path = opts.dir })[1]
	end,
	generator = function(opts)
		local root = vim.fs.root(opts.dir, spec_file)
		if not root then
			return "No " .. spec_file .. " found"
		end
		local spec, err = load_spec(root)
		if not spec then
			return err
		end
		return vim.tbl_map(function(build)
			return {
				name = build.name,
				desc = build.desc,
				params = build.params,
				builder = function(params)
					return {
						name = build.name,
						cmd = rbuild_cmd(spec, build.cmd(params)),
						cwd = root,
						-- A terminal buffer hard-wraps long lines, which breaks errorformat matching.
						strategy = { "jobstart", use_terminal = false },
						components = {
							{
								"on_output_quickfix",
								errorformat = build.errorformat or spec.errorformat,
								open_on_exit = "failure",
								set_diagnostics = true,
							},
							"default",
						},
					}
				end,
			}
		end, spec.builds or {})
	end,
}

local function restart_last()
	local overseer = require("overseer")
	local tasks = overseer.list_tasks({
		status = { overseer.STATUS.SUCCESS, overseer.STATUS.FAILURE, overseer.STATUS.CANCELED },
		sort = require("overseer.task_list").sort_finished_recently,
	})
	if vim.tbl_isempty(tasks) then
		vim.notify("No tasks to restart", vim.log.levels.WARN)
	else
		overseer.run_action(tasks[1], "restart")
	end
end

return {
	"stevearc/overseer.nvim",
	cmd = { "OverseerRun", "OverseerToggle", "OverseerOpen", "OverseerShell", "OverseerTaskAction" },
	keys = {
		{ "<leader>mm", "<cmd>OverseerRun<cr>", desc = "Run Build" },
		{ "<leader>mr", restart_last, desc = "Rerun Last Build" },
		{ "<leader>mo", "<cmd>OverseerToggle<cr>", desc = "Toggle Build Output" },
		{ "<leader>ma", "<cmd>OverseerTaskAction<cr>", desc = "Build Task Action" },
	},
	config = function()
		local overseer = require("overseer")
		overseer.setup({})
		overseer.register_template(provider)
	end,
}

--[[ Example .nvim-build.lua (keep it out of git, e.g. via ~/.config/git/ignore):

return {
	host = "buildbox", -- ssh host; defaults to $RBUILD_HOST, then "buildbox"
	-- relative to the remote $HOME; defaults to this repo's path under the local $HOME
	remote_dir = "src/product-a",
	artifacts = { "build/out" }, -- copied back after a successful build
	builds = {
		{
			name = "waf build",
			params = {
				product = { type = "enum", choices = { "name", "other" }, default = "name" },
				extra = { type = "list", delimiter = " ", optional = true, desc = "Extra waf args" },
			},
			cmd = function(p)
				return vim.list_extend({ "./drun", "./waf", "--product=" .. p.product }, p.extra or {})
			end,
		},
	},
}
]]
