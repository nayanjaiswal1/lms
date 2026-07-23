"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import type { JSONContent } from "@tiptap/react";
import { apiAction, apiUpload } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type {
  AddItemInput,
  CombineSheetsInput,
  CreateSheetInput,
  GrowthScheme,
  ImportedSheetItem,
  ProgressStatus,
  Sheet,
  SheetItem,
  UpdateItemInput,
  UpdateSheetInput,
  UserSheetSettings,
} from "@/lib/server/sheets";

export async function createSheetAction(input: CreateSheetInput): Promise<ActionResult<Sheet>> {
  const result = await apiAction<Sheet>("POST", "/api/sheets", input);
  if (result.ok) revalidatePath(ROUTES.SHEETS, "layout");
  return result;
}

export async function updateSheetAction(sheetId: string, input: UpdateSheetInput): Promise<ActionResult<Sheet>> {
  const result = await apiAction<Sheet>("PATCH", `/api/sheets/${sheetId}`, input);
  if (result.ok) revalidatePath(ROUTES.SHEETS, "layout");
  return result;
}

export async function deleteSheetAction(sheetId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/sheets/${sheetId}`);
  if (result.ok) revalidatePath(ROUTES.SHEETS, "layout");
  return result;
}

// Bound to the sheet id + slug as a form action on the join page. A bare
// `<form action={fn}>` (no useActionState) requires fn to return void, so
// failure can't be returned as an ActionResult — it redirects back to the
// join page with a flash `?error=1` instead. Success redirects straight into
// the sheet, so the join flow needs no client component at all.
export async function joinSheetAction(sheetId: string, slug: string): Promise<void> {
  const result = await apiAction("POST", `/api/sheets/${sheetId}/subscribe`);
  if (!result.ok) {
    redirect(`${ROUTES.sheetJoin(slug)}?error=1`);
  }
  revalidatePath(ROUTES.SHEETS, "layout");
  redirect(ROUTES.sheet(slug));
}

export async function combineSheetsAction(input: CombineSheetsInput): Promise<ActionResult<Sheet>> {
  const result = await apiAction<Sheet>("POST", "/api/sheets/combine", input);
  if (result.ok) revalidatePath(ROUTES.SHEETS, "layout");
  return result;
}

export async function addSheetItemAction(
  sheetId: string,
  input: AddItemInput,
): Promise<ActionResult<SheetItem>> {
  const result = await apiAction<SheetItem>("POST", `/api/sheets/${sheetId}/items`, input);
  if (result.ok) revalidatePath(ROUTES.SHEETS, "layout");
  return result;
}

export async function updateSheetItemAction(
  sheetId: string,
  itemId: string,
  input: UpdateItemInput,
): Promise<ActionResult<SheetItem>> {
  const result = await apiAction<SheetItem>("PATCH", `/api/sheets/${sheetId}/items/${itemId}`, input);
  if (result.ok) revalidatePath(ROUTES.SHEETS, "layout");
  return result;
}

export async function deleteSheetItemAction(sheetId: string, itemId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/sheets/${sheetId}/items/${itemId}`);
  if (result.ok) revalidatePath(ROUTES.SHEETS, "layout");
  return result;
}

export async function importSheetItemsExcelAction(
  formData: FormData,
): Promise<ActionResult<ImportedSheetItem[]>> {
  return apiUpload<ImportedSheetItem[]>("/api/sheets/import/excel", formData);
}

export async function subscribeSheetAction(sheetId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/sheets/${sheetId}/subscribe`);
  if (result.ok) revalidatePath(ROUTES.SHEETS, "layout");
  return result;
}

export async function unsubscribeSheetAction(sheetId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/sheets/${sheetId}/subscribe`);
  if (result.ok) revalidatePath(ROUTES.SHEETS, "layout");
  return result;
}

export async function updateProgressAction(
  topicTag: string,
  status: ProgressStatus,
  sheetId?: string,
): Promise<ActionResult<SheetItem>> {
  const result = await apiAction<SheetItem>("PATCH", `/api/progress/${encodeURIComponent(topicTag)}`, {
    status,
    sheet_id: sheetId,
  });
  if (result.ok) revalidatePath(ROUTES.SHEETS, "layout");
  return result;
}

// The "Next" action — advances an already-solved item to its next, longer
// interval per the sheet's growth scheme, distinct from the status cycle and
// from directly editing the date.
export async function markReviewedAction(
  topicTag: string,
  sheetId: string,
): Promise<ActionResult<SheetItem>> {
  const result = await apiAction<SheetItem>("PATCH", `/api/progress/${encodeURIComponent(topicTag)}/review`, {
    sheet_id: sheetId,
  });
  if (result.ok) revalidatePath(ROUTES.SHEETS, "layout");
  return result;
}

// Reschedules an already-solved item's revision date directly — the
// click-the-date-badge path, separate from the interval picker shown when
// first marking an item solved.
export async function updateProgressRevisionAction(
  topicTag: string,
  revisionAt: string,
): Promise<ActionResult<SheetItem>> {
  const result = await apiAction<SheetItem>("PATCH", `/api/progress/${encodeURIComponent(topicTag)}/revision`, {
    revision_at: revisionAt,
  });
  if (result.ok) revalidatePath(ROUTES.SHEETS, "layout");
  return result;
}

export async function updateSheetSettingsAction(
  sheetId: string,
  baseRevisionDays: number,
  growthScheme: GrowthScheme,
): Promise<ActionResult<UserSheetSettings>> {
  const result = await apiAction<UserSheetSettings>("PUT", "/api/sheets/settings", {
    sheet_id: sheetId,
    base_revision_days: baseRevisionDays,
    growth_scheme: growthScheme,
  });
  if (result.ok) revalidatePath(ROUTES.SHEETS, "layout");
  return result;
}

export async function updateProgressStarredAction(
  topicTag: string,
  starred: boolean,
): Promise<ActionResult<SheetItem>> {
  const result = await apiAction<SheetItem>("PATCH", `/api/progress/${encodeURIComponent(topicTag)}/star`, {
    starred,
  });
  if (result.ok) revalidatePath(ROUTES.SHEETS, "layout");
  return result;
}

// No revalidatePath: this autosaves every couple seconds while the user
// types, and refreshing the whole items list mid-keystroke would remount
// every note editor on the page (same reasoning as lib/wiki/actions.ts).
export async function updateProgressNotesAction(
  topicTag: string,
  notes: JSONContent,
): Promise<ActionResult<SheetItem>> {
  return apiAction<SheetItem>("PATCH", `/api/progress/${encodeURIComponent(topicTag)}/notes`, { notes });
}
