"use server";

import { revalidatePath } from "next/cache";
import { apiAction, apiUpload } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import type { ImportMemberRow } from "@/lib/server/batches";
import ROUTES from "@/lib/routes";

export async function createBatchAction(input: { name: string; description?: string; mentor_id?: string }): Promise<ActionResult> {
  const result = await apiAction("POST", "/api/batches", input);
  if (result.ok) revalidatePath(ROUTES.BATCHES);
  return result;
}

export interface UpdateBatchInput {
  name: string;
  description: string | null;
  mentor_id: string | null;
  starts_at: string | null;
  ends_at: string | null;
}

export async function updateBatchAction(batchId: string, input: UpdateBatchInput): Promise<ActionResult> {
  const result = await apiAction("PATCH", `/api/batches/${batchId}`, input);
  if (result.ok) {
    revalidatePath(ROUTES.BATCHES);
    revalidatePath(ROUTES.batch(batchId));
  }
  return result;
}

export async function addBatchMembersAction(batchId: string, userIds: string[]): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/batches/${batchId}/members`, { user_ids: userIds });
  if (result.ok) {
    revalidatePath(ROUTES.BATCHES);
    revalidatePath(ROUTES.batch(batchId));
  }
  return result;
}

export async function removeBatchMemberAction(batchId: string, userId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/batches/${batchId}/members/${userId}`);
  if (result.ok) {
    revalidatePath(ROUTES.BATCHES);
    revalidatePath(ROUTES.batch(batchId));
  }
  return result;
}

// ─── Bulk student import ────────────────────────────────────────────────────

export async function importParseAction(
  batchId: string,
  formData: FormData,
): Promise<ActionResult<{ rows: ImportMemberRow[] }>> {
  return apiUpload<{ rows: ImportMemberRow[] }>(`/api/batches/${batchId}/import/parse`, formData);
}

export async function importValidateAction(
  batchId: string,
  rows: ImportMemberRow[],
): Promise<ActionResult<{ rows: ImportMemberRow[] }>> {
  return apiAction("POST", `/api/batches/${batchId}/import/validate`, { rows });
}

export interface ConfirmImportInput {
  rows: ImportMemberRow[];
  course_ids: string[];
  mentor_ids: string[];
  locked_fields: string[];
}

export async function confirmImportAction(
  batchId: string,
  input: ConfirmImportInput,
): Promise<ActionResult<{ job_id: string }>> {
  const result = await apiAction<{ job_id: string }>("POST", `/api/batches/${batchId}/import/confirm`, input);
  if (result.ok) {
    revalidatePath(ROUTES.batch(batchId));
  }
  return result;
}
