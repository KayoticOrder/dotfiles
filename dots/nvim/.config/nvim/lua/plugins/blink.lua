return {
	"saghen/blink.cmp",
	dependencies = {
		"rafamadriz/friendly-snippets",
		"giuxtaposition/blink-cmp-copilot",
	},
	-- use a release tag to download pre-built binaries
	version = "1.*",
	---@module 'blink.cmp'
	---@type blink.cmp.Config
	opts = {
		-- C-j/C-k move the selection (j down/next, k up/prev), C-l/C-f accept
		-- (select_and_accept auto-selects the first item if none is selected
		-- yet, matching the old confirm({select=true}))
		keymap = {
			preset = "default",
			["<C-j>"] = { "select_next", "fallback" },
			["<C-k>"] = { "select_prev", "fallback" },
			["<C-l>"] = { "select_and_accept", "fallback" },
			["<C-f>"] = { "select_and_accept", "fallback" },
		},
		appearance = {
			nerd_font_variant = "mono",
		},
		completion = {
			ghost_text = { enabled = true },
		},
		sources = {
			default = { "lsp", "path", "snippets", "buffer", "copilot" },
			providers = {
				copilot = {
					name = "copilot",
					module = "blink-cmp-copilot",
					score_offset = 100,
					async = true,
				},
			},
		},
		cmdline = {
			-- reuse the same C-j/C-k/C-l/C-f overrides for `:`/`/` too
			keymap = { preset = "inherit" },
			completion = {
				menu = { auto_show = true },
				ghost_text = { enabled = true },
			},
		},
		-- SIMD fuzzy matcher; falls back to the lua implementation if the
		-- prebuilt binary isn't available for this platform
		fuzzy = { implementation = "prefer_rust_with_warning" },
	},
	opts_extend = { "sources.default" },
}
