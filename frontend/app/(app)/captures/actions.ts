"use server";

import { revalidatePath } from "next/cache";

import { apiAction, apiUpload, type ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type { Capture, PromoteCaptureInput } from "@/lib/server/captures";

// One or more files (image/pdf) in a single multipart batch — the backend
// creates one Capture row + one processing job per file, so one bad file
// doesn't block the rest (see docs/captures.md).
export async function uploadCapturesAction(formData: FormData): Promise<ActionResult<Capture[]>> {
  const result = await apiUpload<Capture[]>("/api/captures", formData);
  if (result.ok) revalidatePath(ROUTES.CAPTURES);
  return result;
}

// items are whatever the user pasted — each is routed server-side to either
// a link fetch (http/https) or a raw-HTML extraction (anything else), mixed
// freely in one batch.
export async function createCapturesAction(items: string[]): Promise<ActionResult<Capture[]>> {
  const urls = items.filter((item) => item.startsWith("http://") || item.startsWith("https://"));
  const html = items.filter((item) => !urls.includes(item));
  const result = await apiAction<Capture[]>("POST", "/api/captures", { urls, html });
  if (result.ok) revalidatePath(ROUTES.CAPTURES);
  return result;
}

export async function retryCaptureAction(id: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/captures/${encodeURIComponent(id)}/retry`);
  if (result.ok) revalidatePath(ROUTES.CAPTURES);
  return result;
}

export async function dismissCaptureAction(id: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/captures/${encodeURIComponent(id)}/dismiss`);
  if (result.ok) revalidatePath(ROUTES.CAPTURES);
  return result;
}

export async function promoteCaptureAction(id: string, input: PromoteCaptureInput): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/captures/${encodeURIComponent(id)}/promote`, input);
  if (result.ok) revalidatePath(ROUTES.CAPTURES);
  return result;
}
