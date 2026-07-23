"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import { classifyPrepInput, type PrepMode } from "@/lib/interview-prep/classify";
import type { CodingItem, PrepPlan } from "@/lib/server/interview-prep";

const TITLE_MAX_CHARS = 200;
const JD_MAX_CHARS = 10000;

// The form collects one free-text field; this resolves it into the
// structured body the backend expects. modeOverride is only ever set from an
// explicit "switch mode" click — otherwise the mode is always re-derived
// from the text server-side, never trusted from the client, since the text
// (and therefore the correct mode) can change after any client-side guess.
export async function createPrepPlanAction(input: {
  text: string;
  modeOverride?: PrepMode;
  difficulty?: string;
  questionCount?: number;
  category?: "technical" | "behavioral";
}): Promise<ActionResult<PrepPlan>> {
  const text = input.text.trim();
  const mode = input.modeOverride ?? classifyPrepInput(text);

  const body =
    mode === "quick"
      ? {
          mode,
          technology: text,
          difficulty: input.difficulty || "intermediate",
          category: input.category || "technical",
          question_count: input.questionCount || 5,
        }
      : {
          mode,
          job_title: (text.split("\n")[0] || text).slice(0, TITLE_MAX_CHARS).trim() || "Untitled role",
          jd_text: text.length > TITLE_MAX_CHARS || text.includes("\n") ? text.slice(0, JD_MAX_CHARS) : undefined,
        };

  const result = await apiAction<PrepPlan>("POST", "/api/interview-prep", body);
  if (result.ok) revalidatePath(ROUTES.INTERVIEW_PREP);
  return result;
}

export async function submitCodingItemAction(
  planId: string,
  roundId: string,
  itemId: string,
  code: string,
  language: string,
): Promise<ActionResult<CodingItem>> {
  const result = await apiAction<CodingItem>(
    "POST",
    `/api/interview-prep/${planId}/rounds/${roundId}/items/${itemId}/submit`,
    { code, language },
  );
  if (result.ok) revalidatePath(ROUTES.interviewPrepCoding(planId));
  return result;
}
