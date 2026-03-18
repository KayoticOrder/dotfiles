function slugify(raw) {
  if (!raw) return '';
  return raw.trim()
      .toLowerCase()
      .replace(/\s+/g, '-')
      .replace(/[^\w-]/g, '')
      .replace(/-+/g, '-');
}

export {slugify};
