-- Per-repo task definitions live in an untracked .nvim-tasks.lua at the repo root
-- (see the example at the bottom of this file).
local spec_file = ".nvim-tasks.lua"
local old_spec_file = ".nvim-build.lua"
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
	elseif type(spec) ~= "table" then
		return nil, path .. " must return a table"
	end
	if spec.builds ~= nil then
		return nil, path .. ": rename `builds` to `tasks`"
	end
	-- Remote settings used to sit at the top level and on each task; fail loudly rather than
	-- silently running without them.
	local old = { "host", "remote_dir", "sync", "artifacts", "exclude" }
	for _, t in ipairs(vim.list_extend({ spec }, spec.tasks or {})) do
		for _, key in ipairs(old) do
			if t[key] ~= nil then
				local where = t == spec and "" or (" in task '" .. tostring(t.name) .. "'")
				local msg = "%s: move `%s`%s under `remote` (remote_dir is now remote.dir)"
				return nil, msg:format(path, key, where)
			end
		end
	end
	return spec
end

local function find_spec(dir)
	local root = vim.fs.root(dir, { spec_file, old_spec_file })
	if not root then
		return nil, nil, "No " .. spec_file .. " found"
	elseif not vim.uv.fs_stat(vim.fs.joinpath(root, spec_file)) then
		local msg = "%s: rename %s to %s (and `builds` to `tasks`)"
		return nil, nil, msg:format(root, old_spec_file, spec_file)
	end
	return root, load_spec(root)
end

-- Returns nil when the task runs locally. A task's remote table overrides the repo's key by key.
local function remote_opts(spec, task)
	if task.remote == false or (spec.remote == false and task.remote == nil) then
		return nil
	end
	return vim.tbl_extend("force", spec.remote or {}, task.remote or {})
end

local function rbuild_cmd(remote, cmd)
	local ret = { rbuild }
	if remote.checkout then
		table.insert(ret, "-c")
	end
	if remote.sync then
		table.insert(ret, "-s")
	end
	if remote.host then
		vim.list_extend(ret, { "-H", remote.host })
	end
	if remote.dir then
		vim.list_extend(ret, { "-d", remote.dir })
	end
	for _, artifact in ipairs(remote.artifacts or {}) do
		vim.list_extend(ret, { "-a", artifact })
	end
	for _, pattern in ipairs(remote.exclude or {}) do
		vim.list_extend(ret, { "-x", pattern })
	end
	table.insert(ret, "--")
	return vim.list_extend(ret, cmd)
end

local provider = {
	name = "project tasks",
	cache_key = function(opts)
		return vim.fs.find(spec_file, { upward = true, type = "file", path = opts.dir })[1]
	end,
	generator = function(opts)
		local root, spec, err = find_spec(opts.dir)
		if not spec then
			return err
		end
		return vim.tbl_map(function(task)
			return {
				name = task.name,
				desc = task.desc,
				params = task.params,
				builder = function(params)
					local remote = remote_opts(spec, task)
					return {
						name = task.name,
						cmd = remote and rbuild_cmd(remote, task.cmd(params)) or task.cmd(params),
						cwd = root,
						-- A terminal buffer hard-wraps long lines, which breaks errorformat matching.
						strategy = { "jobstart", use_terminal = false },
						components = {
							{
								"on_output_quickfix",
								errorformat = task.errorformat or spec.errorformat,
								open_on_exit = "failure",
								set_diagnostics = true,
							},
							-- open_output skips opening on start when on_output_quickfix is attached
							{ "open_output", on_start = "always" },
							"default",
						},
					}
				end,
			}
		end, spec.tasks or {})
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
local function pick_task()
	local _, spec, err = find_spec(vim.fn.getcwd())
	if not spec then
		return vim.notify(err, vim.log.levels.WARN)
	end
	local fmt = function(task)
		return task.name
	end
	vim.ui.select(spec.tasks or {}, { prompt = "Task", format_item = fmt }, function(task)
		if not task then
			return
		end
		local schema = task.params or {}
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
				return require("overseer").run_task({ name = task.name, params = params })
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
		{ "<leader>mm", pick_task, desc = "Run Task" },
		{ "<leader>mr", restart_last, desc = "Rerun Last Task" },
		{ "<leader>mo", "<cmd>OverseerToggle<cr>", desc = "Toggle Task Output" },
		{ "<leader>ma", "<cmd>OverseerTaskAction<cr>", desc = "Task Action" },
	},
	config = function()
		local overseer = require("overseer")
		overseer.setup({})
		overseer.register_template(provider)
	end,
}

--[[ Example .nvim-tasks.lua (keep it out of git, e.g. via ~/.config/git/ignore):

return {
	errorformat = nil, -- optional, for local and remote tasks; defaults to Vim's 'errorformat'
	-- settings for tasks run on the build machine; `remote = false` makes every task local
	remote = {
		host = "buildbox", -- ssh host; defaults to $RBUILD_HOST, then "buildbox"
		-- relative to the remote $HOME; defaults to this repo's path under the local $HOME
		dir = "src/product-a",
		-- check out your local HEAD commit there first (fetched, detached); discards edits to
		-- tracked files on the build machine, keeps untracked ones. The commit must be pushed.
		checkout = true,
		-- copy the working tree up first (tracked + untracked, minus gitignored);
		-- overwrites remote edits to those files but never deletes remote files
		sync = true,
		-- copied back after a successful run: dirs (mirrored), files, or globs
		artifacts = { "build/out" },
		exclude = { "*.o", "*.map" }, -- rsync patterns skipped when copying artifacts back
	},
	tasks = {
		{
			name = "waf build",
			params = {
				-- params without a default are asked for, in `order`, when the task starts
				product = { type = "enum", choices = { "name", "other" }, order = 1 },
				extra = { type = "list", delimiter = " ", optional = true, order = 2, desc = "Extra waf args" },
			},
			-- overrides the repo's remote settings key by key; the rest (host, sync, ...) still apply
			remote = { artifacts = { "build/out/name/*.bin", "build/out/name/app.elf" } },
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
