<%*
app.commands.addCommand({
    id: "create-term-from-link",
    name: "Create term from link",
    editorCallback: async (editor) => {
        const tp = app.plugins.plugins["templater-obsidian"].templater.current_functions_object;
        await tp.user.createTermFromLink(tp, app);
    }
});
%>
