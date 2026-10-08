/** Shell command (in the lab terminal) that restarts every scenario-owned service. */
export const RESTART_COMMAND = "mf-svc restart-workspace"

/** Shown under every debug ticket: the app does not reload itself after an edit. */
export const RESTART_NOTE =
  "The app runs without auto-reload. After you edit code, restart it from the terminal with"

interface TicketMeta {
  severity: string | null
  reporter: string | null
  /** Brief markdown with the metadata lines removed (they render as header chips). */
  body: string
}

// Matches "Severity: P1", "**Severity:** P1", "- **Reporter**: Dana (Support)".
const META_LINE = /^\s*(?:[-*]\s+)?(?:\*\*|__)?(severity|reporter)(?:\*\*|__)?\s*:\s*(?:\*\*|__)?\s*(.+?)\s*$/i

/** Pulls optional Severity/Reporter lines out of a ticket brief; the rest stays markdown. */
export function parseTicketMeta(brief: string): TicketMeta {
  const meta: Record<string, string> = {}
  let inFence = false
  const kept = brief.split("\n").filter((line) => {
    if (line.trimStart().startsWith("```")) inFence = !inFence
    if (inFence) return true
    const match = META_LINE.exec(line)
    if (!match) return true
    meta[match[1].toLowerCase()] ??= match[2].replace(/\*\*|__/g, "")
    return false
  })
  return {
    severity: meta.severity ?? null,
    reporter: meta.reporter ?? null,
    body: kept.join("\n").trim(),
  }
}
