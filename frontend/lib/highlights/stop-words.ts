// English stop words — a selection made up entirely of these carries no
// meaning to highlight (e.g. just "the" or "and but"), so the popup is
// suppressed rather than saving a useless highlight.
const STOP_WORDS = new Set([
  "a", "an", "the",
  "and", "but", "or", "nor", "so", "yet", "for",
  "of", "to", "in", "on", "at", "by", "with", "from", "into", "onto", "over", "under",
  "is", "are", "was", "were", "be", "been", "being", "do", "does", "did", "has", "have", "had",
  "it", "its", "as", "if", "then", "than", "that", "this", "these", "those",
  "not", "no",
  "i", "you", "he", "she", "we", "they", "them", "his", "her", "our", "your", "their",
])

// True when the selection contains at least one non-stop-word — i.e. it's
// worth showing the highlight popup for.
export function isMeaningfulSelection(text: string): boolean {
  const words = text.trim().toLowerCase().match(/[a-z0-9']+/g)
  if (!words || words.length === 0) return false
  return words.some((w) => !STOP_WORDS.has(w))
}
