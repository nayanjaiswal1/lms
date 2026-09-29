import type { LabKindCatalogConfig } from "@/lib/labs/kinds/catalog"

// Response of GET /sessions/:id/debrief for a debug lab (completed only).
export interface DebugDebriefResponse {
  debrief: { root_cause: string; fix_diff: string }
  score: number
  student_diff?: string
}

// Response of POST /sessions/:id/writeup-review.
export interface WriteupReviewResult {
  covered: string[]
  feedback: string
  passed: boolean
  score_added: number
  reviews_remaining: number
  session_completed: boolean
}

// Server-side cooldown between Checks (backend DebugGradeCooldownSeconds).
// The 429 carries no Retry-After, so the UI mirrors the window.
export const DEBUG_CHECK_COOLDOWN_SECONDS = 30

// Backend caps fresh write-up reviews per session at 3.
export const DEBUG_WRITEUP_MAX_REVIEWS = 3

// Path of the write-up file the reviewer reads (labkinds.DebugKind).
export const DEBUG_WRITEUP_FILE = "INCIDENT.md"

// Learning path from docs/debug-labs.md §5 — a recommended order, not gated.
export const DEBUG_CATALOG: LabKindCatalogConfig = {
  label: "Debug",
  stacks: [
    { value: "django", label: "Django" },
    { value: "fastapi", label: "FastAPI" },
    { value: "react", label: "React" },
    { value: "fullstack", label: "Full stack" },
  ],
  groups: [
    {
      id: "L1",
      label: "L1 · Read the error",
      description: "Configuration mistakes and tracebacks: find the line the error points at.",
      categories: ["config", "errors"],
    },
    {
      id: "L2",
      label: "L2 · Reproduce and step through",
      description: "Use the debugger and tests to follow behavior you cannot see from the ticket.",
      categories: ["react-hooks", "react-state", "react-contract", "service-comm", "security"],
    },
    {
      id: "L3",
      label: "L3 · Data and performance",
      description: "Queries, migrations and slow paths: measure before you change anything.",
      categories: ["data-model", "migrations", "performance", "react-perf", "react-ssr"],
    },
    {
      id: "L4",
      label: "L4 · Concurrency and distributed",
      description: "Races, retries and cross-service failures that only show up under load.",
      categories: ["concurrency", "react-races", "cross-stack"],
    },
  ],
}
