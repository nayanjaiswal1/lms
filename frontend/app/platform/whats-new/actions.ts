"use server";

import { revalidatePath } from "next/cache";
import { apiAction, type ActionResult } from "@/lib/server/api";
import type { WhatsNewEntry } from "@/lib/whats-new";
import ROUTES from "@/lib/routes";

export interface WhatsNewEntryInput {
  title: string;
  description: string;
  icon: string;
  cta_label: string;
  cta_href: string;
  published: boolean;
}

export async function createWhatsNewEntryAction(input: WhatsNewEntryInput): Promise<ActionResult<WhatsNewEntry>> {
  const result = await apiAction<WhatsNewEntry>("POST", "/api/admin/whats-new", input);
  if (result.ok) revalidatePath(ROUTES.PLATFORM_WHATS_NEW);
  return result;
}

export async function updateWhatsNewEntryAction(
  id: string,
  input: WhatsNewEntryInput,
): Promise<ActionResult<WhatsNewEntry>> {
  const result = await apiAction<WhatsNewEntry>("PATCH", `/api/admin/whats-new/${id}`, input);
  if (result.ok) revalidatePath(ROUTES.PLATFORM_WHATS_NEW);
  return result;
}

export async function deleteWhatsNewEntryAction(id: string): Promise<ActionResult<{ status: string }>> {
  const result = await apiAction<{ status: string }>("DELETE", `/api/admin/whats-new/${id}`);
  if (result.ok) revalidatePath(ROUTES.PLATFORM_WHATS_NEW);
  return result;
}
