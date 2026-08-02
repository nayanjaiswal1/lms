export type LabType = 'terminal' | 'code' | 'playground' | 'guided' | 'sandbox'

export type LabWorkspaceLayout = 'split' | 'console'

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
export type SessionEndReason = 'time_limit' | 'idle_timeout'

export interface LabTask {
  task_id: string
  position: number
  title: string
  description: string
  points: number
  is_optional: boolean
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
}

export interface GetSessionResponse {
  session: LabSession
  task_completions: TaskCompletion[]
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

// The backend returns this when a session already reached a terminal state
// (e.g. an auto-expiry job won the race against the client's end request, or
// the user ended it from a different surface). The session is already ended
// either way, so callers should treat this as success, not an error.
export function isLabSessionAlreadyEnded(message: string): boolean {
  return message.toLowerCase().includes('already ended')
}

// A session is "live" (occupying a workspace) while running or paused —
// provisioning/completed/expired/failed/terminated all mean no active UI.
export function isLabSessionActive(status: SessionStatus): boolean {
  return status === 'running' || status === 'paused'
}
