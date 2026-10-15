// Mission workspace of the debug lab kind (org setting Labs > debug UI = "new").
// Server counterparts: backend/internal/labs/mission.go.

// Auto-submit fires this long before the server deadline: the grade is a clean-room
// run that takes a while and the server only accepts a Check that starts before the
// deadline, so submitting at 0 would always be refused.
export const MISSION_AUTO_SUBMIT_LEAD_SECONDS = 20

// The timer turns destructive below this.
export const MISSION_WARNING_SECONDS = 120

// Activity reporting: batched, flushed this often (server cooldown is 2s per session).
export const ACTIVITY_FLUSH_INTERVAL_MS = 5_000
export const ACTIVITY_MAX_BATCH = 50

// A tab-away shorter than this is a glance, not a signal.
export const ACTIVITY_MIN_AWAY_MS = 1_000

export const ACTIVITY_TYPE = {
  TAB_AWAY: "tab_away",
  PASTE: "paste",
  FILE_OPEN: "file_open",
} as const

export type ActivityType = (typeof ACTIVITY_TYPE)[keyof typeof ACTIVITY_TYPE]

export interface ActivityEventInput {
  type: ActivityType
  detail: string
  value: number
}

export interface ActivityEvent extends ActivityEventInput {
  occurred_at: string
}

// Response of GET /sessions/:id/activity.
export interface ActivitySummary {
  tab_away_count: number
  tab_away_total_ms: number
  paste_count: number
  paste_chars: number
  files_opened: { path: string; opens: number }[]
  recent: ActivityEvent[]
}

// Shown on the briefing and the result page: exactly what is recorded.
export const ACTIVITY_DISCLOSURE =
  "The clock starts when you press Start. Time spent in another tab, large pastes and which files you open are recorded and shown with your result."

// Steps of the build screen shown while the sandbox starts (a progress estimate,
// advanced by elapsed time; the last step waits for the real ready signal).
export const MISSION_BUILD_STEPS = [
  { label: "Reading the incident", atSeconds: 0 },
  { label: "Seeding the workspace", atSeconds: 6 },
  { label: "Wiring up the services", atSeconds: 14 },
  { label: "Starting your IDE", atSeconds: 24 },
] as const

// Evidence files are read-only in the IDE (labs.missionIDESettings).
export const MISSION_EVIDENCE_DIR = "evidence"

/** mm:ss, or h:mm:ss from an hour up — the mission clock face. */
export function formatMissionClock(totalSeconds: number): string {
  const s = Math.max(0, Math.floor(totalSeconds))
  const hours = Math.floor(s / 3600)
  const mm = String(Math.floor((s % 3600) / 60)).padStart(2, "0")
  const ss = String(s % 60).padStart(2, "0")
  return hours > 0 ? `${hours}:${mm}:${ss}` : `${mm}:${ss}`
}
