"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type {
  AddItemInput,
  CombineSheetsInput,
  CreateSheetInput,
  ProgressStatus,
  Sheet,
  SheetItem,
  UpdateItemInput,
} from "@/lib/server/sheets";

export async function createSheetAction(input: CreateSheetInput): Promise<ActionResult<Sheet>> {
  const result = await apiAction<Sheet>("POST", "/api/sheets", input);
  if (result.ok) revalidatePath(ROUTES.SHEETS);
  return result;
}

export async function combineSheetsAction(input: CombineSheetsInput): Promise<ActionResult<Sheet>> {
  const result = await apiAction<Sheet>("POST", "/api/sheets/combine", input);
  if (result.ok) revalidatePath(ROUTES.SHEETS);
  return result;
}

export async function addSheetItemAction(
  sheetId: string,
  input: AddItemInput,
): Promise<ActionResult<SheetItem>> {
  const result = await apiAction<SheetItem>("POST", `/api/sheets/${sheetId}/items`, input);
  if (result.ok) revalidatePath(ROUTES.SHEETS);
  return result;
}

export async function updateSheetItemAction(
  sheetId: string,
  itemId: string,
  input: UpdateItemInput,
): Promise<ActionResult<SheetItem>> {
  const result = await apiAction<SheetItem>("PATCH", `/api/sheets/${sheetId}/items/${itemId}`, input);
  if (result.ok) revalidatePath(ROUTES.SHEETS);
  return result;
}

export async function deleteSheetItemAction(sheetId: string, itemId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/sheets/${sheetId}/items/${itemId}`);
  if (result.ok) revalidatePath(ROUTES.SHEETS);
  return result;
}

export async function subscribeSheetAction(sheetId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/sheets/${sheetId}/subscribe`);
  if (result.ok) revalidatePath(ROUTES.SHEETS);
  return result;
}

export async function unsubscribeSheetAction(sheetId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/sheets/${sheetId}/subscribe`);
  if (result.ok) revalidatePath(ROUTES.SHEETS);
  return result;
}

export async function updateProgressAction(
  topicTag: string,
  status: ProgressStatus,
): Promise<ActionResult<SheetItem>> {
  const result = await apiAction<SheetItem>("PATCH", `/api/progress/${encodeURIComponent(topicTag)}`, { status });
  if (result.ok) revalidatePath(ROUTES.SHEETS);
  return result;
}
