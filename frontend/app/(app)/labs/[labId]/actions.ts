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
} from "@/lib/labs"

export async function startLabSessionAction(
  labId: string,
  idempotencyKey: string,
): Promise<ActionResult<LabSession>> {
  return apiAction<LabSession>(
    "POST",
    `/api/labs/${labId}/sessions`,
    undefined,
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
