export type LabType = 'terminal' | 'code' | 'playground' | 'guided' | 'sandbox' | 'debug'

type LabWorkspaceLayout = 'split' | 'console'

export type LabCodeLanguage = 'javascript' | 'python' | 'typescript'

export interface VerifyTaskResult {
  passed: boolean
  attempts: number
  score_added: number
  stdout: string
  stderr: string
  session_completed: boolean
}

export type SessionStatus =
  | 'provisioning'
  | 'running'
  | 'paused'
  | 'completed'
  | 'expired'
  | 'failed'
  | 'terminated_abuse'

export type TaskStatus = 'pending' | 'passed' | 'skipped'

// Set only by the lab.expire_sessions background job — distinguishes an
// automatic reaper termination from a normal user-driven end/completion
// (which leaves the session's end_reason null).
type SessionEndReason = 'time_limit' | 'idle_timeout'

type LabTaskGrader = 'script' | 'writeup_review'

export interface LabTask {
  task_id: string
  position: number
  title: string
  description: string
  points: number
  is_optional: boolean
  // 'script' tasks are graded by Check; 'writeup_review' tasks by submitting
  // a write-up (no hints, no Check).
  grader: LabTaskGrader
}

export interface Lab {
  id: string
  title: string
  lab_type: LabType
  // Authoritative language for "code" type labs; null for other lab types.
  // The editor locks to this value instead of offering an independent
  // language switcher that can drift from what the tasks actually verify.
  language: LabCodeLanguage | null
  max_duration: number
  max_resets: number
  hint_penalty_pct: number
  description: string | null
  layout: LabWorkspaceLayout
  // Container port of the lab's running app; 0 = no live preview pane.
  preview_port: number
  // Whether the lab has an instructor-authored sample-test script (sandbox
  // Run button). The script body itself never reaches the client.
  has_run_script: boolean
  // Whether the lab's environment image bundles kubectl/a cluster — gates
  // the Resources tab and the file editor's Validate button, both
  // meaningless on a plain container (e.g. mindforge/lab-docker).
  has_cluster: boolean
  tasks: LabTask[]
}

// One listening TCP port detected inside the session container.
export interface LabPort {
  port: number
  // Best-effort process name (e.g. "node", "postgres") resolved server-side
  // via a /proc fd inode walk; empty when the owning process couldn't be
  // identified.
  process_name?: string
}

export interface LabPortsData {
  ports: LabPort[]
}

// Response of POST /sessions/:id/run — raw sample-test output.
export interface LabRunResult {
  exit_code: number
  stdout: string
  stderr: string
}

export interface LabSubmitTaskResult {
  task_id: string
  passed: boolean
  // Failure hint context (verification scripts echo hints to stdout).
  stdout?: string
  stderr?: string
}

// Response of POST /sessions/:id/submit — batch hidden-test outcome.
export interface LabSubmitResult {
  results: LabSubmitTaskResult[]
  score: number
  session_completed: boolean
}

export interface TaskCompletion {
  task_id: string
  status: TaskStatus
  attempts: number
  hints_used: number
}

// Response of POST /sessions/:id/tasks/:taskId/hint. hint_penalty_pct
// mirrors the lab's own (Lab.hint_penalty_pct) — included per-response so
// the hint drawer's warning never needs a second prop plumbed down just for
// this.
export interface HintResult {
  level: number
  content: string
  hints_used: number
  hints_remaining: number
  hint_penalty_pct: number
}

export const MAX_HINTS_PER_TASK = 3

export interface LabSession {
  id: string
  lab_id: string
  status: SessionStatus
  score: number
  reset_count: number
  expires_at: string
  started_at: string
  completed_at: string | null
  last_active_at: string
  end_reason: SessionEndReason | null
  // Set only for composed lab kinds (e.g. debug) once a scenario variant is picked.
  variant_key?: string | null
  // Set once every required task passed but the session awaits Finish
  // (kinds with the 'finish' completion policy).
  required_passed_at?: string | null
}

// Student-safe workspace block of a "debug" lab (GET /sessions/:id) — never
// the root cause, fix or rubric.
interface DebugSessionBlock {
  brief: string
  ide_port: number
  app_ports: number[]
}

// Kind-specific blocks GET /sessions/:id returns, keyed by lab_type. A new
// lab kind adds one optional entry here.
export interface LabKindBlocks {
  debug?: DebugSessionBlock
}

export type LabKindBlock = NonNullable<LabKindBlocks[keyof LabKindBlocks]>

export type GetSessionResponse = {
  session: LabSession
  task_completions: TaskCompletion[]
} & LabKindBlocks

// One catalog row (GET /api/labs/catalog) — the caller's best status included.
export type LabCatalogStatus = 'not_started' | 'in_progress' | 'completed'

export interface LabCatalogEntry {
  lab_id: string
  title: string
  lab_type: LabType
  stack: string
  category: string
  difficulty: string
  skills: string[]
  max_duration: number
  status: LabCatalogStatus
  /** Highest score over completed attempts; null when never passed. */
  best_score: number | null
}

export interface ActiveLabSession {
  session_id: string
  lab_id: string
  lab_title: string
  lab_type: LabType
  status: SessionStatus
  started_at: string
  expires_at: string
  last_active_at: string
}

// Longest a Check may stay pending client-side: the backend's 5-minute batch
// deadline (maxSubmitAllDuration) plus slack. Past it the UI shows a retryable error.
export const LAB_CHECK_CLIENT_TIMEOUT_MS = 310_000

// Machine-readable error codes from the API error envelope ({"error","code"}).
// Mirrors the Go constants in backend/internal/labs/codes.go — keep in sync.
export const LAB_ERROR_CODES = {
  sessionExpired: 'lab_session_expired',
  sessionCompletedAtDeadline: 'lab_session_completed_at_deadline',
  sessionAlreadyEnded: 'lab_session_already_ended',
  rateLimited: 'rate_limited',
  graderBusy: 'grader_busy',
  graderTimeout: 'grader_timeout',
  hintNotSupported: 'hint_not_supported',
  maxHintsReached: 'max_hints_reached',
  writeupReviewLimit: 'writeup_review_limit',
  snippetDailyLimit: 'snippet_daily_limit',
  aiUnavailable: 'ai_unavailable',
  notFound: 'lab_not_found',
  forbidden: 'lab_forbidden',
  sessionActive: 'lab_session_active',
  capacityReached: 'lab_capacity_reached',
  userHasActiveSession: 'lab_other_session_active',
  sessionNotRunning: 'lab_session_not_running',
  noRunScript: 'lab_no_run_script',
  labNotPublished: 'lab_not_published',
  maxResetsReached: 'max_resets_reached',
  taskNotOptional: 'task_not_optional',
  executorUnavailable: 'executor_unavailable',
  invalidPath: 'invalid_path',
  imageNotAllowed: 'lab_image_not_allowed',
  provisioningUnstable: 'lab_provisioning_unstable',
  resetFailed: 'lab_reset_failed',
  labTypeUnsupported: 'lab_type_unsupported',
  contentTooLarge: 'content_too_large',
  kindLabNotBuilt: 'lab_not_built',
  bundleStoreUnavailable: 'bundle_store_unavailable',
  noDebrief: 'debrief_unavailable',
} as const

// The session already reached a terminal state (e.g. an auto-expiry job won
// the race against the client's end request, or the user ended it from a
// different surface). It is ended either way, so callers treat this as
// success, not an error.
export function isLabSessionAlreadyEnded(code: string | undefined): boolean {
  return code === LAB_ERROR_CODES.sessionAlreadyEnded
}

// A request noticed the hard deadline and the lab closed as completed
// (required tasks had passed): the lab succeeded, time just ran out.
export function isLabCompletedAtDeadline(code: string | undefined): boolean {
  return code === LAB_ERROR_CODES.sessionCompletedAtDeadline
}

// The session hit its deadline and closed without completing.
export function isLabSessionExpired(code: string | undefined): boolean {
  return code === LAB_ERROR_CODES.sessionExpired
}

// A session is "live" (occupying a workspace) while running or paused —
// provisioning/completed/expired/failed/terminated all mean no active UI.
export function isLabSessionActive(status: SessionStatus): boolean {
  return status === 'running' || status === 'paused'
}
