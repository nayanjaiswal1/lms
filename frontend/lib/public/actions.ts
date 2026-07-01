"use server";

import type { ActionResult } from "@/lib/server/api";
import type { PublicSession } from "@/lib/server/public";

function publicBase(): string {
  const url = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!url) return "";
  return url;
}

export async function startPublicAttemptAction(
  code: string,
  body: { name: string; email: string; phone?: string },
): Promise<ActionResult<PublicSession>> {
  const url = publicBase();
  if (!url) return { error: "Service unavailable." };
  try {
    const res = await fetch(`${url}/api/p/${code}/start`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      cache: "no-store",
    });
    const json = await res.json().catch(() => ({})) as { data?: PublicSession; error?: string };
    if (!res.ok) return { error: json.error ?? "Could not start the test." };
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
  const url = publicBase();
  if (!url) return { error: "Service unavailable." };
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
    };
    if (!res.ok) return { error: json.error ?? "Could not submit." };
    return { ok: true, data: json.data };
  } catch {
    return { error: "Network error. Please try again." };
  }
}
