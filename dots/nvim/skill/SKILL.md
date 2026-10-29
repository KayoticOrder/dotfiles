---
name: nvim-tasks
description: Set up, change, or debug the user's per-repo Neovim tasks (builds, flashing, running, tests), which run through overseer.nvim either locally or on a remote build machine via `rbuild`, configured by an untracked `.nvim-tasks.lua` at the repo root. Use when the user wants to add tasks for a repo, add or change a task's command or arguments, set up the build machine or SSH for remote tasks, or when a task, artifact copy-back, checkout, sync, or quickfix list isn't working.
---

# Neovim project tasks

The source of truth is the code; read it when a detail here doesn't settle a question:
- `~/.local/bin/rbuild`: runs a command in the same repo on the build machine over ssh, rewrites remote paths in its output to local ones, and rsyncs artifacts back on success.
- `~/.config/nvim/lua/plugins/overseer.lua`: loads `.nvim-tasks.lua`, turns each entry into an overseer task, and fills the quickfix list on failure. The bottom of the file has an example.

If either file is missing, stop and tell the user to run `./install-standalone nvim` from their dotfiles.

## `.nvim-tasks.lua` (one per repo, at the repo root)

```lua
return {
	errorformat = nil, -- optional; for local and remote tasks; default is Vim's 'errorformat'
	remote = { -- optional; settings for tasks run on the build machine, or `false` to make every task local
		host = "buildbox", -- optional; ssh host, else $RBUILD_HOST, else "buildbox"
		dir = "src/x", -- optional; relative to remote $HOME, else the repo's path under local $HOME
		checkout = true, -- optional; fetch and check out the local HEAD commit there first (detached, submodules updated)
		sync = true, -- optional; copy the working tree up first (tracked + untracked, minus gitignored, submodules too)
		artifacts = { "build/out" }, -- optional; repo-relative dirs (mirrored), files or globs, copied back after a successful run
		exclude = { "*.o" }, -- optional; rsync patterns skipped when copying artifacts back
	},
	tasks = {
		{
			name = "build", -- shown in the picker; also what a dap config's `preLaunchTask` names
			params = { -- overseer params: string, number, integer, boolean, list, enum
				product = { type = "enum", choices = { "a", "b" } },
			},
			cmd = function(p) return { "./waf", "--product=" .. p.product } end, -- argv list, run from the repo root
			remote = nil, -- optional; omit to use the repo's `remote`, `false` to run locally,
			--               or a table that overrides the repo's `remote` key by key (e.g. just `artifacts`)
			errorformat = nil, -- optional; overrides the top-level one
		},
	},
}
```

- **Any command:** tasks aren't limited to builds. Flashing, running the app, or tests are just more entries; ones that use files on this machine (e.g. flashing from copied-back artifacts) want `remote = false`.
- **Prompting:** `<leader>mm` asks for every param without a `default`, one at a time in `order` (then by name): a picker for `enum`/`boolean`, a text prompt otherwise. A param with a `default` is filled in silently; `optional = true` may be left blank. Pick defaults based on whether the user wants to be asked. (`:OverseerRun` and a dap `preLaunchTask` use overseer's own form instead, whose enum choices only appear with nvim-cmp, which this config doesn't use; give such tasks defaults.)
- **`checkout` is destructive on the build machine:** it treats that checkout as a mirror. Each run leaves it on a detached HEAD at the local commit and throws away edits to tracked files there (untracked files and commits are kept). Make sure the user doesn't edit on the build machine before turning it on.
- **Old files:** a `.nvim-build.lua` (the old name) or a `builds` key fails with an error saying to rename it to `.nvim-tasks.lua` / `tasks`. Top-level `host`/`remote_dir`/`sync`/`artifacts`/`exclude`, or per-task `artifacts`/`exclude`, fail with an error naming the key: move them under `remote`, renaming `remote_dir` to `dir`. Also update the user's `~/.config/git/ignore` line for the new name.
- **Artifacts:** a dir is mirrored (local files missing remotely are deleted, except ones matching `exclude`); files and globs are just copied. An entry that matches nothing fails the task even if the command passed.
- **Keep it out of git:** it must never be committed. Check with `git check-ignore -v .nvim-tasks.lua`; if it isn't ignored, offer to add `.nvim-tasks.lua` to `~/.config/git/ignore`.
- **Trust:** Neovim asks the user to trust the file the first time and after every change (`vim.secure.read`). Tell them to expect that prompt after you edit it.

## Setting up a repo

1. Work out how the repo builds and runs before asking: README, build scripts and wrappers (e.g. `./drun`), CI config, `wscript`/Makefile/CMakeLists, flash/run scripts. Find where outputs land for `remote.artifacts` (often already in `.gitignore`).
2. Ask the user only for what you can't find: which products/targets and arguments they use, which they want to be asked for each time, and whether to `checkout` and/or `sync`. Remote settings go in `remote`; give a task its own `remote` table only for what differs.
3. Write `.nvim-tasks.lua`, then make sure it's ignored (above).
4. Give the user the equivalent terminal command to try, e.g. `rbuild -c -s -a build/out -- ./drun ./waf --product=a`. Don't run it yourself without asking: it runs on a shared machine, `-c` discards edits there, and `-s` overwrites the remote copies of the user's files.

## Machine setup (once)

- **Your computer:** a `Host` entry in `~/.ssh/config` with `ControlMaster auto`, `ControlPath ~/.ssh/cm-%r@%h:%p`, `ControlPersist 10m` (rbuild makes several ssh calls per run), and key auth via `ssh-copy-id`. Show the user the entry rather than editing their ssh config unasked.
- **Build machine:** the repo cloned (at the same path under `$HOME`, or set `remote.dir`) and `rsync` installed.

## Troubleshooting

- **"the input device is not a TTY":** remote tasks get a terminal (`ssh -tt`), so this should only happen for a `remote = false` task, which runs without one. Have the wrapper add `-t` to `docker run` only when `[ -t 0 ]`.
- **Output only appears at the end:** `rbuild` gives remote tasks a terminal so they flush line by line, and its `sed` runs unbuffered. A local task has no terminal, so a program that buffers when piped (Python, including waf) holds its output; set `PYTHONUNBUFFERED=1` or the tool's own flag in its `cmd`.
- **Builds stale code / line numbers don't match:** the build machine has its own checkout; enable `checkout` (committed state) and/or `sync` (uncommitted edits), or have the user push and pull.
- **"commit … is not on the build machine; push it first":** `checkout` fetches from the build machine's own remotes, so the local HEAD commit (and any submodule commits it points at) must be pushed somewhere those remotes reach.
- **Quickfix entries point at missing files:** check that the output's paths are under the remote repo root (only that prefix is rewritten) or relative to a directory the output announces ("Entering directory"). Errors from paths outside the repo (system headers, other checkouts) can't be mapped.
- **No tasks in the picker:** Neovim's cwd must be inside the repo; check `:messages` for a Lua error, a rename error, or "is not trusted" (they denied the trust prompt; `:trust` re-allows the current file).
- **Long lines wrap or colors show up in output:** the task already uses a non-terminal buffer, and `rbuild` strips color codes from remote output; leftover escape codes are ones its pattern doesn't cover, so turn color off in the command itself (e.g. `--color=never`).
- **Artifacts didn't come back:** they're only copied after the command exits 0, only the entries listed (a task's `remote.artifacts` replaces the repo's list rather than adding to it), and never ones matching `exclude`.
