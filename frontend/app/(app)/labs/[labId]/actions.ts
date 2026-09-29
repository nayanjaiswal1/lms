"use server"
import { apiAction } from "@/lib/server/api"
import type { ActionResult } from "@/lib/server/api"
import type {
  LabSession,
  VerifyTaskResult,
  GetSessionResponse,
  LabPortsData,
  LabRunResult,
  LabSubmitResult,
  HintResult,
} from "@/lib/labs"
import type { WriteupReviewResult } from "@/lib/labs/kinds/debug"

export async function startLabSessionAction(
  labId: string,
  idempotencyKey: string,
  moduleId?: string,
): Promise<ActionResult<LabSession>> {
  return apiAction<LabSession>(
    "POST",
    `/api/labs/${labId}/sessions`,
    moduleId ? { module_id: moduleId } : undefined,
    { "Idempotency-Key": idempotencyKey },
  )
}

export async function mintWSTokenAction(
  sessionId: string,
): Promise<ActionResult<{ session_token: string }>> {
  return apiAction<{ session_token: string }>(
    "POST",
    `/api/labs/sessions/${sessionId}/ws-token`,
  )
}

export async function endLabSessionAction(
  sessionId: string,
): Promise<ActionResult<unknown>> {
  return apiAction<unknown>("POST", `/api/labs/sessions/${sessionId}/end`)
}

export async function resetLabSessionAction(
  sessionId: string,
): Promise<ActionResult<GetSessionResponse>> {
  return apiAction<GetSessionResponse>("POST", `/api/labs/sessions/${sessionId}/reset`)
}

export async function verifyLabTaskAction(
  sessionId: string,
  taskId: string,
  code: string,
): Promise<ActionResult<VerifyTaskResult>> {
  return apiAction<VerifyTaskResult>(
    "POST",
    `/api/labs/sessions/${sessionId}/tasks/${taskId}/verify`,
    { code },
  )
}

// idempotencyKey is derived per (session, task, next level) by the caller so a
// double-click / retry replays the same result instead of burning two levels.
export async function requestLabHintAction(
  sessionId: string,
  taskId: string,
  idempotencyKey?: string,
): Promise<ActionResult<HintResult>> {
  return apiAction<HintResult>(
    "POST",
    `/api/labs/sessions/${sessionId}/tasks/${taskId}/hint`,
    undefined,
    idempotencyKey ? { "Idempotency-Key": idempotencyKey } : undefined,
  )
}

export async function listLabPortsAction(
  sessionId: string,
): Promise<ActionResult<LabPortsData>> {
  return apiAction<LabPortsData>("GET", `/api/labs/sessions/${sessionId}/ports`)
}

export async function runLabScriptAction(
  sessionId: string,
): Promise<ActionResult<LabRunResult>> {
  return apiAction<LabRunResult>("POST", `/api/labs/sessions/${sessionId}/run`)
}

export async function submitLabAction(
  sessionId: string,
): Promise<ActionResult<LabSubmitResult>> {
  return apiAction<LabSubmitResult>("POST", `/api/labs/sessions/${sessionId}/submit`)
}

// Reads INCIDENT.md from the student's workspace server-side and scores it
// against the lab's rubric (429 after 3 reviews, 503 when the AI is down).
export async function reviewLabWriteupAction(
  sessionId: string,
): Promise<ActionResult<WriteupReviewResult>> {
  return apiAction<WriteupReviewResult>(
    "POST",
    `/api/labs/sessions/${sessionId}/writeup-review`,
  )
}

// Authoritative task completions + score, used by kind workspaces after
// operations (Check, write-up review) whose response doesn't carry them all.
export async function getLabSessionAction(
  sessionId: string,
): Promise<ActionResult<GetSessionResponse>> {
  return apiAction<GetSessionResponse>("GET", `/api/labs/sessions/${sessionId}`)
}
