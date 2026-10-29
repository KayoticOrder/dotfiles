---
name: remote-builds
description: Set up, change, or debug the user's Neovim build setup, where builds run on a remote build machine (or locally) through `rbuild` and overseer.nvim, configured per repo by an untracked `.nvim-build.lua`. Use when the user wants to add builds for a repo, add or change a build's command or arguments, set up the build machine or SSH for it, or when a build, artifact copy-back, sync, or quickfix list isn't working.
---

# Remote builds

The source of truth is the code; read it when a detail here doesn't settle a question:
- `~/.local/bin/rbuild`: runs a command in the same repo on the build machine over ssh, rewrites remote paths in its output to local ones, and rsyncs artifact folders back on success.
- `~/.config/nvim/lua/plugins/overseer.lua`: loads `.nvim-build.lua`, turns each build into an overseer task, and fills the quickfix list on failure. The bottom of the file has an example.

If either file is missing, stop and tell the user to run `./install-standalone nvim` from their dotfiles.

## `.nvim-build.lua` (one per repo, at the repo root)

```lua
return {
	errorformat = nil, -- optional; for local and remote builds; default is Vim's 'errorformat'
	remote = { -- optional; settings for builds run on the build machine, or `false` to make every build local
		host = "buildbox", -- optional; ssh host, else $RBUILD_HOST, else "buildbox"
		dir = "src/x", -- optional; relative to remote $HOME, else the repo's path under local $HOME
		sync = true, -- optional; copy the working tree up first (tracked + untracked, minus gitignored, submodules too)
		artifacts = { "build/out" }, -- optional; repo-relative dirs (mirrored), files or globs, copied back after a successful build
		exclude = { "*.o" }, -- optional; rsync patterns skipped when copying artifacts back
	},
	builds = {
		{
			name = "build", -- shown in the picker
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

- **Prompting:** `<leader>mm` asks for every param without a `default`, one at a time in `order` (then by name): a picker for `enum`/`boolean`, a text prompt otherwise. A param with a `default` is filled in silently; `optional = true` may be left blank. Pick defaults based on whether the user wants to be asked. (`:OverseerRun` uses overseer's own form instead, whose enum choices only appear with nvim-cmp, which this config doesn't use.)
- **Old layout:** files from before `remote` existed (top-level `host`/`remote_dir`/`sync`/`artifacts`/`exclude`, or per-build `artifacts`/`exclude`) fail to load with an error naming the key. Move them under `remote`, renaming `remote_dir` to `dir`.
- **Artifacts:** a dir is mirrored (local files missing remotely are deleted, except ones matching `exclude`); files and globs are just copied. An entry that matches nothing fails the task even if the build passed.
- **Keep it out of git:** it must never be committed. Check with `git check-ignore -v .nvim-build.lua`; if it isn't ignored, offer to add `.nvim-build.lua` to `~/.config/git/ignore`.
- **Trust:** Neovim asks the user to trust the file the first time and after every change (`vim.secure.read`). Tell them to expect that prompt after you edit it.

## Setting up a repo

1. Work out how the repo builds before asking: README, build scripts and wrappers (e.g. `./drun`), CI config, `wscript`/Makefile/CMakeLists. Find where outputs land for `remote.artifacts` (often already in `.gitignore`).
2. Ask the user only for what you can't find: which products/targets and arguments they use, which they want to be asked for each time, and whether to `sync`. Remote settings go in `remote`; give a build its own `remote` table only for what differs.
3. Write `.nvim-build.lua`, then make sure it's ignored (above).
4. Give the user the equivalent terminal command to try, e.g. `rbuild -s -a build/out -- ./drun ./waf --product=a`. Don't run it yourself without asking: it runs a build on a shared machine, and `-s` overwrites the remote copies of the user's files.

## Machine setup (once)

- **Your computer:** a `Host` entry in `~/.ssh/config` with `ControlMaster auto`, `ControlPath ~/.ssh/cm-%r@%h:%p`, `ControlPersist 10m` (rbuild makes several ssh calls per build), and key auth via `ssh-copy-id`. Show the user the entry rather than editing their ssh config unasked.
- **Build machine:** the repo cloned (at the same path under `$HOME`, or set `remote.dir`) and `rsync` installed.

## Troubleshooting

- **"the input device is not a TTY":** the build wrapper passes `-t`/`-it` to `docker run`, but builds run without a terminal. It should only add `-t` when `[ -t 0 ]`.
- **Builds stale code / line numbers don't match:** the build machine has its own checkout; enable `sync` or have the user push and pull.
- **Quickfix entries point at missing files:** check that the output's paths are under the remote repo root (only that prefix is rewritten) or relative to a directory the output announces ("Entering directory"). Errors from paths outside the repo (system headers, other checkouts) can't be mapped.
- **No builds in the picker:** Neovim's cwd must be inside the repo; check `:messages` for a Lua error or "is not trusted" (they denied the trust prompt; `:trust` re-allows the current file).
- **Long lines wrap or colors show up in output:** the task already uses a non-terminal buffer; color must be coming from the command itself, so turn it off there (e.g. `--color=never`).
- **Artifacts didn't come back:** they're only copied after the build exits 0, only the entries listed (a build's `remote.artifacts` replaces the repo's list rather than adding to it), and never ones matching `exclude`.
