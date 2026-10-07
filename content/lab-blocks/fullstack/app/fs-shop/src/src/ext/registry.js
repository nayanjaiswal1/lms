// Extensions add actions to the Orders "Tools" group. Each one lives in
// src/ext/<name>/index.js and default-exports { id, label, run(orders) }, where
// run returns the text to show. They are discovered here, so adding an
// extension never touches the pages.
const modules = import.meta.glob('./*/index.js', { eager: true });

export const extensions = Object.values(modules)
  .map((module) => module.default)
  .filter(Boolean)
  .sort((a, b) => a.id.localeCompare(b.id));
