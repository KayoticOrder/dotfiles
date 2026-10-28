return {
	"weirongxu/plantuml-previewer.vim",
	ft = { "plantuml" },
	cmd = { "PlantumlOpen", "PlantumlToggle", "PlantumlSave" },
	dependencies = {
		"tyru/open-browser.vim",
		-- provides the plantuml filetype; without it ft never triggers
		"aklt/plantuml-syntax",
	},
}
