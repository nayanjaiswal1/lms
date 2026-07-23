"use server";

import { revalidatePath } from "next/cache";
import { apiAction, apiUpload } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import { getBatchImportReport, getOrgId } from "@/lib/server/batches";
import type { ImportMemberRow, ImportReport } from "@/lib/server/batches";
import { fetchJob } from "@/lib/jobs/server";
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

export interface ImportJobStatus {
  status: string;
  lastError: string | null;
  isTerminal: boolean;
  report: ImportReport | null;
}

const TERMINAL_JOB_STATUSES = ["success", "failed", "dead", "cancelled"];

// getImportJobStatusAction lets the bulk-import dialog check on a running
// job without a full page navigation — the wizard fetches this once up
// front (server-rendered) and again on demand via a "Check status" click.
export async function getImportJobStatusAction(batchId: string, jobId: string): Promise<ActionResult<ImportJobStatus>> {
  const orgId = await getOrgId();
  if (!orgId) return { error: "Session expired." };
  try {
    const detail = await fetchJob(orgId, jobId);
    const isTerminal = TERMINAL_JOB_STATUSES.includes(detail.job.status);
    const report = isTerminal ? await getBatchImportReport(batchId).catch(() => null) : null;
    return { ok: true, data: { status: detail.job.status, lastError: detail.job.last_error, isTerminal, report } };
  } catch {
    return { error: "Could not load import status." };
  }
}

// ─── Batch invitations ──────────────────────────────────────────────────────

export async function resendBatchInvitationAction(batchId: string, invitationId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/batches/${batchId}/invitations/${invitationId}/resend`);
  if (result.ok) revalidatePath(ROUTES.batch(batchId));
  return result;
}

export async function revokeBatchInvitationAction(batchId: string, invitationId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/batches/${batchId}/invitations/${invitationId}`);
  if (result.ok) revalidatePath(ROUTES.batch(batchId));
  return result;
}

// ─── Classroom Test Assessment Engine ───────────────────────────────────────

export interface EnterOfflineTestScoresInput {
  test_name: string;
  test_date: string; // YYYY-MM-DD
  max_score: number;
  scores: { user_id: string; score: number }[];
}

export async function enterOfflineTestScoresAction(
  batchId: string,
  input: EnterOfflineTestScoresInput,
): Promise<ActionResult<{ test_id: string }>> {
  const result = await apiAction<{ test_id: string }>("POST", `/api/batches/${batchId}/offline-tests`, input);
  if (result.ok) revalidatePath(`${ROUTES.batch(batchId)}/tests`);
  return result;
}

export async function updateOfflineTestScoreAction(
  batchId: string,
  testId: string,
  userId: string,
  score: number,
): Promise<ActionResult> {
  const result = await apiAction(
    "PATCH",
    `/api/batches/${batchId}/offline-tests/${testId}/scores/${userId}`,
    { score },
  );
  if (result.ok) revalidatePath(`${ROUTES.batch(batchId)}/tests/${testId}`);
  return result;
}
