"use server"
import { apiAction } from "@/lib/server/api"
import type { ActionResult } from "@/lib/server/api"
import type { LabFileEntry, ValidateResult, LabResourcesData } from "@/lib/labs/files"

export async function listLabFilesAction(sessionId: string): Promise<ActionResult<LabFileEntry[]>> {
  return apiAction<LabFileEntry[]>("GET", `/api/labs/sessions/${sessionId}/files`)
}

export async function readLabFileAction(
  sessionId: string,
  path: string,
): Promise<ActionResult<{ content: string }>> {
  return apiAction<{ content: string }>(
    "GET",
    `/api/labs/sessions/${sessionId}/files/read?path=${encodeURIComponent(path)}`,
  )
}

export async function writeLabFileAction(
  sessionId: string,
  path: string,
  content: string,
): Promise<ActionResult<{ ok: boolean }>> {
  return apiAction<{ ok: boolean }>("PUT", `/api/labs/sessions/${sessionId}/files`, { path, content })
}

export async function createLabDirectoryAction(
  sessionId: string,
  path: string,
): Promise<ActionResult<{ ok: boolean }>> {
  return apiAction<{ ok: boolean }>("POST", `/api/labs/sessions/${sessionId}/files/mkdir`, { path })
}

export async function renameLabFileAction(
  sessionId: string,
  from: string,
  to: string,
): Promise<ActionResult<{ ok: boolean }>> {
  return apiAction<{ ok: boolean }>("POST", `/api/labs/sessions/${sessionId}/files/rename`, { from, to })
}

export async function deleteLabFileAction(
  sessionId: string,
  path: string,
): Promise<ActionResult<{ ok: boolean }>> {
  return apiAction<{ ok: boolean }>(
    "DELETE",
    `/api/labs/sessions/${sessionId}/files?path=${encodeURIComponent(path)}`,
  )
}

export async function validateLabFileAction(
  sessionId: string,
  path: string,
): Promise<ActionResult<ValidateResult>> {
  return apiAction<ValidateResult>("POST", `/api/labs/sessions/${sessionId}/files/validate`, { path })
}

export async function getLabResourcesAction(
  sessionId: string,
): Promise<ActionResult<LabResourcesData>> {
  return apiAction<LabResourcesData>("GET", `/api/labs/sessions/${sessionId}/resources`)
}
