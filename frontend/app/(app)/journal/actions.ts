"use server";

import { revalidatePath } from "next/cache";

import { apiAction, type ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type {
  CreateJournalEntryInput,
  CreateJournalEntryResult,
  JournalEntry,
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

// Suggestion only — never writes to the database. The caller reviews the
// suggested category/subcategory/title and creates the entry itself via
// createJournalEntryAction, using the pasted text as content verbatim.
export async function structureJournalEntryAction(text: string): Promise<ActionResult<StructureJournalEntryResult>> {
  return apiAction<StructureJournalEntryResult>("POST", "/api/journal/structure", { text });
}
