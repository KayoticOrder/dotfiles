<%*
const title = await tp.system.prompt("Note name");
const id = title.toLowerCase().replace(/\s+/g, "-");
await tp.file.rename(id);

tR += `---
id: ${id}
tags:
categories:
created: ${tp.date.now("YYYY-MM-DD HH:mm")}
---
# ${title}
`;
%>