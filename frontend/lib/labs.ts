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
}

export interface GetSessionResponse {
  session: LabSession
  task_completions: TaskCompletion[]
}
