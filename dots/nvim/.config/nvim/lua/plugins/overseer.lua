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

local function rbuild_cmd(spec, build, cmd)
	local ret = { rbuild }
	if spec.sync then
		table.insert(ret, "-s")
	end
	if spec.host then
		vim.list_extend(ret, { "-H", spec.host })
	end
	if spec.remote_dir then
		vim.list_extend(ret, { "-d", spec.remote_dir })
	end
	for _, artifact in ipairs(build.artifacts or spec.artifacts or {}) do
		vim.list_extend(ret, { "-a", artifact })
	end
	for _, pattern in ipairs(build.exclude or spec.exclude or {}) do
		vim.list_extend(ret, { "-x", pattern })
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
						cmd = build.remote == false and build.cmd(params)
							or rbuild_cmd(spec, build, build.cmd(params)),
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

local function parse_input(param, input)
	local t = param.type or "string"
	if t == "list" then
		return vim.split(input, param.delimiter or ",", { plain = true, trimempty = true })
	elseif t == "number" or t == "integer" then
		return tonumber(input)
	end
	return input
end

-- Calls done(ok, value); ok is false when the user cancels or gives an invalid value.
local function prompt_param(name, param, done)
	local label = param.name or name
	if param.type == "enum" or param.type == "boolean" then
		local choices = param.type == "boolean" and { true, false } or param.choices
		vim.ui.select(choices, { prompt = label, format_item = tostring }, function(choice)
			done(choice ~= nil, choice)
		end)
		return
	end
	local prompt = label .. (param.desc and " (" .. param.desc .. ")" or "") .. ": "
	vim.ui.input({ prompt = prompt }, function(input)
		if input == nil then
			return done(false)
		elseif input == "" then
			if not param.optional then
				vim.notify(label .. " is required", vim.log.levels.ERROR)
			end
			return done(param.optional == true, nil)
		end
		local value = parse_input(param, input)
		if value == nil then
			local msg = string.format("Invalid %s for %s: %s", param.type, label, input)
			vim.notify(msg, vim.log.levels.ERROR)
		end
		done(value ~= nil, value)
	end)
end

-- overseer's own form only offers enum choices through nvim-cmp (this config uses blink), so
-- ask for every param without a default here via vim.ui.select/input (snacks) and hand
-- overseer a complete set, which skips its form.
local function run_build()
	local root = vim.fs.root(vim.fn.getcwd(), spec_file)
	local spec, err
	if root then
		spec, err = load_spec(root)
	else
		err = "No " .. spec_file .. " found"
	end
	if not spec then
		return vim.notify(err, vim.log.levels.WARN)
	end
	local fmt = function(build)
		return build.name
	end
	vim.ui.select(spec.builds or {}, { prompt = "Build", format_item = fmt }, function(build)
		if not build then
			return
		end
		local schema = build.params or {}
		local names = vim.tbl_filter(function(name)
			return schema[name].default == nil
		end, vim.tbl_keys(schema))
		table.sort(names, function(a, b)
			local oa, ob = schema[a].order or math.huge, schema[b].order or math.huge
			return oa == ob and a < b or oa < ob
		end)
		local params = {}
		local function ask(i)
			if i > #names then
				return require("overseer").run_task({ name = build.name, params = params })
			end
			prompt_param(names[i], schema[names[i]], function(ok, value)
				if ok then
					params[names[i]] = value
					ask(i + 1)
				end
			end)
		end
		ask(1)
	end)
end

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
		{ "<leader>mm", run_build, desc = "Run Build" },
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
	-- copied back after a successful build: dirs (mirrored), files, or globs
	artifacts = { "build/out" },
	exclude = { "*.o", "*.map" }, -- rsync patterns skipped when copying artifacts back
	-- copy the working tree up first (tracked + untracked, minus gitignored);
	-- overwrites remote edits to those files but never deletes remote files
	sync = true,
	builds = {
		{
			name = "waf build",
			params = {
				-- params without a default are asked for, in `order`, when the build starts
				product = { type = "enum", choices = { "name", "other" }, order = 1 },
				extra = { type = "list", delimiter = " ", optional = true, order = 2, desc = "Extra waf args" },
			},
			-- overrides the top-level artifacts/exclude for this build only
			artifacts = { "build/out/name/*.bin", "build/out/name/app.elf" },
			cmd = function(p)
				return vim.list_extend({ "./drun", "./waf", "--product=" .. p.product }, p.extra or {})
			end,
		},
		{
			name = "waf build (local)",
			remote = false, -- run on this machine instead of the build machine
			params = { product = { type = "enum", choices = { "name", "other" } } },
			cmd = function(p)
				return { "./waf", "--product=" .. p.product }
			end,
		},
	},
}
]]
