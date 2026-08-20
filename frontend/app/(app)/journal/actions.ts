"use server";

import { revalidatePath } from "next/cache";

import { apiAction, type ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type {
  CreateJournalEntryInput,
  CreateJournalEntryResult,
  JournalEntry,
  MergeJournalEntriesResult,
  StructureJournalEntryResult,
  UpdateJournalEntryInput,
} from "@/lib/server/journal";

export async function createJournalEntryAction(
  input: CreateJournalEntryInput,
): Promise<ActionResult<CreateJournalEntryResult>> {
  const result = await apiAction<CreateJournalEntryResult>("POST", "/api/journal", input);
  if (result.ok) revalidatePath(ROUTES.JOURNAL);
  return result;
}

export async function updateJournalEntryAction(
  id: string,
  input: UpdateJournalEntryInput,
): Promise<ActionResult<JournalEntry>> {
  const result = await apiAction<JournalEntry>("PATCH", `/api/journal/${encodeURIComponent(id)}`, input);
  if (result.ok) revalidatePath(ROUTES.JOURNAL);
  return result;
}

export async function deleteJournalEntryAction(id: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/journal/${encodeURIComponent(id)}`);
  if (result.ok) revalidatePath(ROUTES.JOURNAL);
  return result;
}

// Destructive: otherId's content is appended onto keepId and otherId is
// deleted, atomically (backend transaction). The caller holds the response's
// `removed` entry (plus keepId's pre-merge content) to offer Ctrl+Z undo via
// undoJournalMergeAction.
export async function mergeJournalEntriesAction(
  keepId: string,
  otherId: string,
): Promise<ActionResult<MergeJournalEntriesResult>> {
  const result = await apiAction<MergeJournalEntriesResult>("POST", `/api/journal/${encodeURIComponent(keepId)}/merge`, {
    other_id: otherId,
  });
  if (result.ok) revalidatePath(ROUTES.JOURNAL);
  return result;
}

// Reverses one merge: restores keepId's content to what it was before the
// merge, then recreates the removed entry (a new row/id — only its fields
// need to come back, not its original identity). Single-level undo, scoped
// to the most recent merge only.
export async function undoJournalMergeAction(
  keepId: string,
  keepContentBeforeMerge: string,
  removed: JournalEntry,
): Promise<ActionResult> {
  const restoreKept = await apiAction("PATCH", `/api/journal/${encodeURIComponent(keepId)}`, {
    content: keepContentBeforeMerge,
  });
  if (!restoreKept.ok) return restoreKept;

  const recreateRemoved = await apiAction("POST", "/api/journal", {
    entry_date: removed.entry_date,
    category: removed.category,
    subcategory: removed.subcategory,
    title: removed.title,
    content: removed.content,
  });
  if (!recreateRemoved.ok) return recreateRemoved;

  revalidatePath(ROUTES.JOURNAL);
  return { ok: true };
}

// Suggestion only — never writes to the database. The caller reviews the
// suggested category/subcategory/title and creates the entry itself via
// createJournalEntryAction, using the pasted text as content verbatim.
export async function structureJournalEntryAction(text: string): Promise<ActionResult<StructureJournalEntryResult>> {
  return apiAction<StructureJournalEntryResult>("POST", "/api/journal/structure", { text });
}
