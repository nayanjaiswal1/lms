export type LabType = 'terminal' | 'code' | 'playground' | 'guided'

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
  tasks: LabTask[]
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
