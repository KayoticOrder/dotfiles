# Glossary
```dataview
TABLE WITHOUT ID
    link(file.path, term) AS Term,
    definition AS Definition,
    related AS Related
FROM "terms"
WHERE type = "term"
SORT term ASC
```