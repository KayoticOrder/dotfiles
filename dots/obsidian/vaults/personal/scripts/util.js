function slugify(text) {
  return text.toLowerCase()
      .trim()
      .replace(/[\s_]+/g, '-')
      .replace(/[^\w-]/g, '')
      .replace(/--+/g, '-');
}

function toTitleCase(text) {
  return text.replace(/[-_]+/g, ' ')
      .replace(
          /\w\S*/g, w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase());
}

module.exports = {
  slugify,
  toTitleCase
};