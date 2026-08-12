// Static literal classes (not string-templated) so Tailwind sees every class
// at build time — same requirement components/habits/habit-color-picker.tsx
// documents for its HABIT_SWATCH_CLASS map. Reuses the existing bg-habit-*
// design tokens (global CSS vars, not habits-feature-owned) rather than
// adding a new color set just for this.
const TAG_SWATCH_CLASSES = [
  "bg-habit-blue",
  "bg-habit-orange",
  "bg-habit-aqua",
  "bg-habit-yellow",
  "bg-habit-magenta",
  "bg-habit-green",
  "bg-habit-violet",
  "bg-habit-red",
] as const;

// Deterministic per category+subcategory pair — every entry in the same
// "box" (e.g. Backend / Redis) always renders the same dot color, regardless
// of list order. Plain string hash, not cryptographic.
export function journalTagSwatchClass(category: string, subcategory: string): string {
  const key = `${category.toLowerCase()}|${subcategory.toLowerCase()}`;
  let hash = 0;
  for (let i = 0; i < key.length; i++) {
    hash = (hash * 31 + key.charCodeAt(i)) | 0;
  }
  return TAG_SWATCH_CLASSES[Math.abs(hash) % TAG_SWATCH_CLASSES.length];
}
