async function createTermFromLink(tp, app) {
  const editor = app.workspace.activeEditor?.editor;
  const cursor = editor.getCursor();
  const line = editor.getLine(cursor.line);

  const wikilinkRe = /\[\[([^\]|]+)(?:\|[^\]]*)?\]\]/g;
  let match, found, matchStart, matchEnd;
  while ((match = wikilinkRe.exec(line)) !== null) {
    const start = match.index;
    const end = match.index + match[0].length;
    if (cursor.ch >= start && cursor.ch <= end) {
      found = match[1].trim();
      matchStart = start;
      matchEnd = end;
      break;
    }
  }

  if (!found) {
    new Notice('No wikilink found under cursor.');
    return;
  }

  const title = tp.user.util.toTitleCase(found);
  const termFolder = 'terms';
  const id = tp.user.util.slugify(title);
  const template = tp.file.find_tfile('term');

  // rewrite [[My Term]] → [[my-term|My Term]] in the source note
  if (title !== id) {
    const newLink = `[[${id}|${title}]]`;
    editor.replaceRange(
        newLink, {line: cursor.line, ch: matchStart},
        {line: cursor.line, ch: matchEnd});
  }

  // ensure folder exists
  if (!app.vault.getAbstractFileByPath(termFolder)) {
    await app.vault.createFolder(termFolder);
  }

  // stash original title so term.md can access it
  window._termTitle = title;

  await tp.file.create_new(
      template, id, true, app.vault.getAbstractFileByPath(termFolder));
}

module.exports = createTermFromLink;
