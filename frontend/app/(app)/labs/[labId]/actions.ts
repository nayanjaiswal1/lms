"use server"
import { cookies } from "next/headers"
import { apiAction } from "@/lib/server/api"
import type { ActionResult } from "@/lib/server/api"
import type { LabSession, VerifyTaskResult, GetSessionResponse } from "@/lib/labs"

export async function startLabSessionAction(
  labId: string,
  idempotencyKey: string,
): Promise<ActionResult<LabSession>> {
  const url = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL
  if (!url) return { error: "Service unavailable." }
  try {
    const store = await cookies()
    const accessToken = store.get("access_token")?.value ?? ""
    const csrfToken = store.get("csrf_token")?.value ?? ""
    const res = await fetch(`${url}/api/labs/${labId}/sessions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Cookie: `access_token=${accessToken}; csrf_token=${csrfToken}`,
        "X-CSRF-Token": csrfToken,
        "Idempotency-Key": idempotencyKey,
      },
      cache: "no-store",
    })
    if (res.status === 429) {
      const raw = res.headers.get("Retry-After")
      const wait = raw ? parseInt(raw, 10) : 60
      return {
        error: `Too many requests. Please wait ${isNaN(wait) ? 60 : wait} seconds before trying again.`,
      }
    }
    const json = (await res.json().catch(() => ({}))) as {
      data?: LabSession
      error?: string
    }
    if (!res.ok) return { error: json.error ?? "Failed to start lab session." }
    return { ok: true, data: json.data }
  } catch {
    return { error: "Network error. Please try again." }
  }
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
  language: string,
): Promise<ActionResult<VerifyTaskResult>> {
  return apiAction<VerifyTaskResult>(
    "POST",
    `/api/labs/sessions/${sessionId}/tasks/${taskId}/verify`,
    { code, language },
  )
}
