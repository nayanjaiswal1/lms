"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type { WorkspaceComment } from "@/lib/workspace/phase3-server";
import type {
  AskQuestionResult,
  BriefView,
  CreateWorkItemResult,
  DocView,
  Meeting,
  ReviewVerdict,
  RequirementGaps,
  RequirementQuestion,
  ScheduleMeetingInput,
  Standup,
  TriageBugInput,
  WorkItem,
} from "@/lib/workspace/types";

// ── Request-body shapes the contract names (AskQuestionRequest,
// AnswerQuestionRequest, ReviewDocRequest, RecordAttendanceRequest,
// ActionItemRequest, PostStandupRequest) but that types.ts (lead-owned)
// doesn't declare — same "local type in your own file" convention
// actions.ts/items-actions.ts already use. Flagged in the final report for
// the lead to fold into types.ts if another agent needs the same shape. ──

interface AskQuestionInput {
  question: string;
}

interface AnswerQuestionInput {
  answer?: string;
  is_assumption?: boolean;
}

interface ReviewDocInput {
  verdict: ReviewVerdict;
  comment?: string;
  wiki_version: number;
}

export interface RecordAttendanceInput {
  occurrence_at: string;
  attendance: { user_id: string; attended: boolean }[];
}

export interface ActionItemInput {
  title: string;
  description?: string;
  force?: boolean;
}

interface PostStandupInput {
  yesterday: string;
  today: string;
  blockers?: string;
}

interface CommentInput {
  content: string;
}

// ── Requirement Q&A ──────────────────────────────────────────────────────────

export async function askQuestionAction(workspaceId: string, question: string): Promise<ActionResult<AskQuestionResult>> {
  const result = await apiAction<AskQuestionResult>("POST", `/api/workspaces/${workspaceId}/questions`, { question } satisfies AskQuestionInput);
  if (result.ok) revalidatePath(ROUTES.workspaceRequirement(workspaceId));
  return result;
}

export async function similarQuestionsAction(workspaceId: string, q: string): Promise<ActionResult<RequirementQuestion[]>> {
  return apiAction<RequirementQuestion[]>("GET", `/api/workspaces/${workspaceId}/questions/similar?q=${encodeURIComponent(q)}`);
}

export async function answerQuestionAction(
  workspaceId: string,
  questionId: string,
  input: AnswerQuestionInput,
): Promise<ActionResult<RequirementQuestion>> {
  const result = await apiAction<RequirementQuestion>("POST", `/api/workspaces/${workspaceId}/questions/${questionId}/answer`, input);
  if (result.ok) revalidatePath(ROUTES.workspaceRequirement(workspaceId));
  return result;
}

export async function requirementGapsAction(workspaceId: string): Promise<ActionResult<RequirementGaps>> {
  return apiAction<RequirementGaps>("POST", `/api/workspaces/${workspaceId}/requirement/gaps`);
}

// ── Brief ────────────────────────────────────────────────────────────────────

export async function createBriefAction(workspaceId: string): Promise<ActionResult<BriefView>> {
  const result = await apiAction<BriefView>("POST", `/api/workspaces/${workspaceId}/brief`);
  if (result.ok) revalidatePath(ROUTES.workspaceBrief(workspaceId));
  return result;
}

export async function approveBriefAction(workspaceId: string): Promise<ActionResult<BriefView>> {
  const result = await apiAction<BriefView>("POST", `/api/workspaces/${workspaceId}/brief/approve`);
  if (result.ok) revalidatePath(ROUTES.workspaceBrief(workspaceId));
  return result;
}

// ── Doc gate ─────────────────────────────────────────────────────────────────

export async function submitDocAction(workspaceId: string, itemId: string): Promise<ActionResult<DocView>> {
  const result = await apiAction<DocView>("POST", `/api/workspaces/${workspaceId}/items/${itemId}/doc/submit`);
  if (result.ok) {
    revalidatePath(ROUTES.workspaceBoard(workspaceId));
    revalidatePath(ROUTES.workspaceList(workspaceId));
  }
  return result;
}

export async function reviewDocAction(
  workspaceId: string,
  itemId: string,
  input: ReviewDocInput,
): Promise<ActionResult<DocView>> {
  const result = await apiAction<DocView>("POST", `/api/workspaces/${workspaceId}/items/${itemId}/doc/reviews`, input);
  if (result.ok) {
    revalidatePath(ROUTES.workspaceBoard(workspaceId));
    revalidatePath(ROUTES.workspaceList(workspaceId));
  }
  return result;
}

export async function scheduleDesignReviewAction(
  workspaceId: string,
  itemId: string,
  input: ScheduleMeetingInput,
): Promise<ActionResult<Meeting>> {
  const result = await apiAction<Meeting>("POST", `/api/workspaces/${workspaceId}/items/${itemId}/doc/design-review`, input);
  if (result.ok) revalidatePath(ROUTES.workspaceMeetings(workspaceId));
  return result;
}

// ── Bug triage ───────────────────────────────────────────────────────────────

export async function triageBugAction(
  workspaceId: string,
  itemId: string,
  input: TriageBugInput,
): Promise<ActionResult<WorkItem>> {
  const result = await apiAction<WorkItem>("POST", `/api/workspaces/${workspaceId}/items/${itemId}/triage`, input);
  if (result.ok) {
    revalidatePath(ROUTES.workspaceBugs(workspaceId));
    revalidatePath(ROUTES.workspaceBoard(workspaceId));
    revalidatePath(ROUTES.workspaceList(workspaceId));
  }
  return result;
}

// ── Meetings & standups ──────────────────────────────────────────────────────

export async function scheduleMeetingAction(workspaceId: string, input: ScheduleMeetingInput): Promise<ActionResult<Meeting>> {
  const result = await apiAction<Meeting>("POST", `/api/workspaces/${workspaceId}/meetings`, input);
  if (result.ok) revalidatePath(ROUTES.workspaceMeetings(workspaceId));
  return result;
}

export async function recordAttendanceAction(workspaceId: string, eventId: string, input: RecordAttendanceInput): Promise<ActionResult> {
  const result = await apiAction("PUT", `/api/workspaces/${workspaceId}/meetings/${eventId}/attendance`, input);
  if (result.ok) revalidatePath(ROUTES.workspaceMeetings(workspaceId));
  return result;
}

export async function convertActionItemAction(
  workspaceId: string,
  eventId: string,
  input: ActionItemInput,
): Promise<ActionResult<CreateWorkItemResult>> {
  const result = await apiAction<CreateWorkItemResult>("POST", `/api/workspaces/${workspaceId}/meetings/${eventId}/action-items`, input);
  if (result.ok && result.data?.item.id) {
    revalidatePath(ROUTES.workspaceBoard(workspaceId));
    revalidatePath(ROUTES.workspaceList(workspaceId));
  }
  return result;
}

export async function postStandupAction(workspaceId: string, input: PostStandupInput): Promise<ActionResult<Standup>> {
  const result = await apiAction<Standup>("PUT", `/api/workspaces/${workspaceId}/standups`, input);
  if (result.ok) revalidatePath(ROUTES.workspaceMeetings(workspaceId));
  return result;
}

// ── Comments (items + questions) ────────────────────────────────────────────

export async function createQuestionCommentAction(
  workspaceId: string,
  questionId: string,
  content: string,
): Promise<ActionResult<WorkspaceComment>> {
  return apiAction<WorkspaceComment>("POST", `/api/workspaces/${workspaceId}/questions/${questionId}/comments`, { content } satisfies CommentInput);
}

export async function createItemCommentAction(
  workspaceId: string,
  itemId: string,
  content: string,
): Promise<ActionResult<WorkspaceComment>> {
  return apiAction<WorkspaceComment>("POST", `/api/workspaces/${workspaceId}/items/${itemId}/comments`, { content } satisfies CommentInput);
}
