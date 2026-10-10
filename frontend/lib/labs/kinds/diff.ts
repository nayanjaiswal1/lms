export type DiffRowKind = "add" | "remove" | "context" | "hunk"

export interface DiffRow {
  kind: DiffRowKind
  /** Line number in the new file (add/context) or the old file (remove); null on hunk headers. */
  lineNumber: number | null
  text: string
}

export interface DiffFile {
  path: string
  rows: DiffRow[]
}

const HUNK_HEADER = /^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@(.*)$/
const FILE_HEADER = /^diff --git a\/(.+?) b\/(.+)$/

/**
 * Splits a unified diff into per-file row lists with line numbers. The git
 * header lines (diff --git, index, ---/+++, mode lines) are consumed, not rendered.
 */
export function parseUnifiedDiff(diff: string): DiffFile[] {
  const files: DiffFile[] = []
  let current: DiffFile | null = null
  let inHunk = false
  let oldLine = 0
  let newLine = 0

  for (const line of diff.replace(/\r?\n$/, "").split(/\r?\n/)) {
    const header = FILE_HEADER.exec(line)
    if (header) {
      current = { path: header[2], rows: [] }
      files.push(current)
      inHunk = false
      continue
    }
    const hunk = HUNK_HEADER.exec(line)
    if (hunk) {
      if (!current) {
        current = { path: "changes", rows: [] }
        files.push(current)
      }
      oldLine = Number(hunk[1])
      newLine = Number(hunk[2])
      inHunk = true
      current.rows.push({ kind: "hunk", lineNumber: null, text: hunk[3].trim() })
      continue
    }
    if (!current || !inHunk) continue // git metadata before the first hunk
    if (line.startsWith("\\")) continue // "\ No newline at end of file"
    if (line.startsWith("+")) {
      current.rows.push({ kind: "add", lineNumber: newLine++, text: line.slice(1) })
    } else if (line.startsWith("-")) {
      current.rows.push({ kind: "remove", lineNumber: oldLine++, text: line.slice(1) })
    } else {
      current.rows.push({ kind: "context", lineNumber: newLine, text: line.slice(1) })
      oldLine++
      newLine++
    }
  }
  return files
}
