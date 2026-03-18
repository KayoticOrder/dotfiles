<%*
const title = await tp.system.prompt("Note name");
const id = tp.user.util.slugify(title);
await tp.file.rename(id);
-%>
---
id: <% id %>
tags:
categories:
created: <% tp.date.now("YYYY-MM-DD HH:mm") %>
---
# <% title %>