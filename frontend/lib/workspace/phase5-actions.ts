"use server";

import { revalidatePath } from "next/cache";
import { apiAction, authHeaders, baseURL } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type {
  AssigneeSuggestion,
  ChangeImpact,
  CloseSprintInput,
  CreateReleaseInput,
  CreateSprintInput,
  ExportKind,
  IssueCertificateInput,
  ItemSuggestions,
  LateExplanation,
  MemberReport,
  PeerFeedbackInput,
  Release,
  ReleaseNotes,
  SetItemReleaseInput,
  SetItemSprintInput,
  Sprint,
  UpdateReleaseInput,
  WeeklySummary,
  WorkItem,
} from "@/lib/workspace/types";

// ── Releases ─────────────────────────────────────────────────────────────────

export async function createReleaseAction(workspaceId: string, input: CreateReleaseInput): Promise<ActionResult<Release>> {
  const result = await apiAction<Release>("POST", `/api/workspaces/${workspaceId}/releases`, input);
  if (result.ok) revalidatePath(ROUTES.workspaceReleases(workspaceId));
  return result;
}

export async function updateReleaseAction(
  workspaceId: string,
  releaseId: string,
  input: UpdateReleaseInput,
): Promise<ActionResult<Release>> {
  const result = await apiAction<Release>("PATCH", `/api/workspaces/${workspaceId}/releases/${releaseId}`, input);
  if (result.ok) revalidatePath(ROUTES.workspaceReleases(workspaceId));
  return result;
}

export async function getReleaseNotesAction(
  workspaceId: string,
  releaseId: string,
  polish: boolean,
): Promise<ActionResult<ReleaseNotes>> {
  const qs = polish ? "?polish=true" : "";
  return apiAction<ReleaseNotes>("GET", `/api/workspaces/${workspaceId}/releases/${releaseId}/notes${qs}`);
}

export async function setItemReleaseAction(
  workspaceId: string,
  itemId: string,
  input: SetItemReleaseInput,
): Promise<ActionResult<WorkItem>> {
  const result = await apiAction<WorkItem>("PUT", `/api/workspaces/${workspaceId}/items/${itemId}/release`, input);
  if (result.ok) revalidatePath(ROUTES.workspaceReleases(workspaceId));
  return result;
}

// ── Sprints ──────────────────────────────────────────────────────────────────

export async function createSprintAction(workspaceId: string, input: CreateSprintInput): Promise<ActionResult<Sprint>> {
  const result = await apiAction<Sprint>("POST", `/api/workspaces/${workspaceId}/sprints`, input);
  if (result.ok) revalidatePath(ROUTES.workspaceSprints(workspaceId));
  return result;
}

export async function startSprintAction(workspaceId: string, sprintId: string): Promise<ActionResult<Sprint>> {
  const result = await apiAction<Sprint>("POST", `/api/workspaces/${workspaceId}/sprints/${sprintId}/start`);
  if (result.ok) revalidatePath(ROUTES.workspaceSprints(workspaceId));
  return result;
}

export async function closeSprintAction(
  workspaceId: string,
  sprintId: string,
  input: CloseSprintInput,
): Promise<ActionResult<Sprint>> {
  const result = await apiAction<Sprint>("POST", `/api/workspaces/${workspaceId}/sprints/${sprintId}/close`, input);
  if (result.ok) revalidatePath(ROUTES.workspaceSprints(workspaceId));
  return result;
}

export async function setItemSprintAction(
  workspaceId: string,
  itemId: string,
  input: SetItemSprintInput,
): Promise<ActionResult<WorkItem>> {
  const result = await apiAction<WorkItem>("PUT", `/api/workspaces/${workspaceId}/items/${itemId}/sprint`, input);
  if (result.ok) revalidatePath(ROUTES.workspaceSprints(workspaceId));
  return result;
}

// ── Completion: feedback, member report, certificates, showcase ─────────────

export async function submitPeerFeedbackAction(workspaceId: string, input: PeerFeedbackInput): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/workspaces/${workspaceId}/feedback`, input);
  if (result.ok) revalidatePath(ROUTES.workspaceFeedback(workspaceId));
  return result;
}

export async function issueCertificateAction(
  workspaceId: string,
  input: IssueCertificateInput,
): Promise<ActionResult<MemberReport>> {
  const result = await apiAction<MemberReport>("POST", `/api/workspaces/${workspaceId}/certificates`, input);
  if (result.ok) revalidatePath(ROUTES.workspaceMemberReport(workspaceId, input.user_id));
  return result;
}

export async function setShowcaseOptInAction(workspaceId: string, optIn: boolean): Promise<ActionResult> {
  const result = await apiAction("PUT", `/api/workspaces/${workspaceId}/membership/showcase`, { opt_in: optIn });
  if (result.ok) revalidatePath(ROUTES.workspaceFeedback(workspaceId));
  return result;
}

// ── AI suggestions (contract-phase5.md 5c) — suggest-only, never auto-applied ─

export async function suggestEpicsAction(workspaceId: string): Promise<ActionResult<ItemSuggestions>> {
  return apiAction<ItemSuggestions>("POST", `/api/workspaces/${workspaceId}/ai/epics`);
}

export async function suggestTaskBreakdownAction(workspaceId: string, itemId: string): Promise<ActionResult<ItemSuggestions>> {
  return apiAction<ItemSuggestions>("POST", `/api/workspaces/${workspaceId}/items/${itemId}/ai/breakdown`);
}

export async function suggestAssigneesAction(workspaceId: string, itemId: string): Promise<ActionResult<AssigneeSuggestion[]>> {
  return apiAction<AssigneeSuggestion[]>("POST", `/api/workspaces/${workspaceId}/items/${itemId}/ai/assignees`);
}

export async function explainLateAction(workspaceId: string, itemId: string): Promise<ActionResult<LateExplanation>> {
  return apiAction<LateExplanation>("POST", `/api/workspaces/${workspaceId}/items/${itemId}/ai/why-late`);
}

export async function changeImpactAction(workspaceId: string, itemId: string): Promise<ActionResult<ChangeImpact>> {
  return apiAction<ChangeImpact>("POST", `/api/workspaces/${workspaceId}/items/${itemId}/ai/change-impact`);
}

export async function getWeeklySummaryAction(workspaceId: string, regenerate: boolean): Promise<ActionResult<WeeklySummary>> {
  const qs = regenerate ? "?regenerate=true" : "";
  return apiAction<WeeklySummary>("POST", `/api/workspaces/${workspaceId}/ai/weekly-summary${qs}`);
}

// ── CSV export (contract-phase5.md 5d) ───────────────────────────────────────
// apiAction/apiGet assume a JSON {data} envelope; the export endpoint streams
// plain text/csv, so this does its own minimal fetch reusing baseURL()/
// authHeaders() (the same building blocks, not a raw hand-built Cookie
// header) rather than forcing a non-JSON response through the JSON helpers.
export async function exportWorkspaceCSVAction(workspaceId: string, kind: ExportKind): Promise<ActionResult<string>> {
  let url: string;
  try {
    url = baseURL();
  } catch {
    return { error: "Service unavailable." };
  }
  try {
    const res = await fetch(`${url}/api/workspaces/${workspaceId}/export/${kind}.csv`, {
      headers: await authHeaders(),
      cache: "no-store",
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({})) as { error?: string };
      return { error: body.error ?? "Export failed." };
    }
    return { ok: true, data: await res.text() };
  } catch {
    return { error: "Network error. Please try again." };
  }
}
