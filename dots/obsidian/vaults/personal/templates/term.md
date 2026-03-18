<%*
const fromLink = window._termTitle != null;
const raw = fromLink ? window._termTitle : await tp.system.prompt("Term name");
const title = tp.user.util.toTitleCase(raw);
const id = fromLink ? tp.file.title : tp.user.util.slugify(title);
const alias = fromLink && title !== id ? title : null;
if (fromLink) window._termTitle = null;
else await tp.file.rename(id);
-%>
---
id: <% id %>
type: term
term: <% title %>
topics:
related: []
aliases: <% alias ? `["${alias}"]` : "[]" %>
tags:
created: <% tp.date.now("YYYY-MM-DD HH:mm") %>
---
# <% title %>
(definition:: )
## Examples
-
## Notes
-