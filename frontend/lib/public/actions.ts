"use server";

import { actionErrorMessage, baseURL, type ActionResult } from "@/lib/server/api";
import type { PublicSession } from "@/lib/server/public";

export async function startPublicAttemptAction(
  code: string,
  body: { name: string; email: string; phone?: string },
): Promise<ActionResult<PublicSession>> {
  let url: string;
  try {
    url = baseURL();
  } catch {
    return { error: "Service unavailable." };
  }
  try {
    const res = await fetch(`${url}/api/p/${code}/start`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      cache: "no-store",
    });
    const json = await res.json().catch(() => ({})) as { data?: PublicSession; error?: string; fields?: Record<string, string> };
    if (!res.ok) return { error: actionErrorMessage(json, "Could not start the test."), fieldErrors: json.fields };
    return { ok: true, data: json.data };
  } catch {
    return { error: "Network error. Please try again." };
  }
}

export async function submitPublicAttemptAction(
  code: string,
  token: string,
  answers: Record<string, string[]>,
): Promise<ActionResult<{ percentage: number; passed: boolean; score: number; max_score: number }>> {
  let url: string;
  try {
    url = baseURL();
  } catch {
    return { error: "Service unavailable." };
  }
  // Convert {aqId: [optionId, ...]} to {aqId: {selected: [optionId, ...]}}
  const payload: Record<string, { selected: string[] }> = {};
  for (const [aqId, selected] of Object.entries(answers)) {
    payload[aqId] = { selected };
  }
  try {
    const res = await fetch(`${url}/api/p/${code}/submit/${token}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ answers: payload }),
      cache: "no-store",
    });
    const json = await res.json().catch(() => ({})) as {
      data?: { percentage: number; passed: boolean; score: number; max_score: number };
      error?: string;
      fields?: Record<string, string>;
    };
    if (!res.ok) return { error: actionErrorMessage(json, "Could not submit."), fieldErrors: json.fields };
    return { ok: true, data: json.data };
  } catch {
    return { error: "Network error. Please try again." };
  }
}
