"use server";

import { revalidatePath } from "next/cache";
import { authHeaders, baseURL } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export interface FormState {
  error?: string;
  fieldErrors?: Record<string, string>;
  ok?: boolean;
}

export interface MCQOptionInput {
  text: string;
  is_correct: boolean;
}

export interface CreateQuestionInput {
  type: "mcq" | "coding";
  title: string;
  difficulty: string;
  default_points: number;
  tags: string[];
  // MCQ
  prompt: string;
  multiple?: boolean;
  options?: MCQOptionInput[];
  explanation?: string;
  // Coding
  languages?: string[];
  starter_code?: Record<string, string>;
  time_limit_ms?: number;
  memory_limit_kb?: number;
  test_cases?: { stdin: string; expected: string; hidden: boolean; weight: number }[];
}

// createQuestionAction builds the typed content payload and posts a new question.
export async function createQuestionAction(input: CreateQuestionInput): Promise<FormState> {
  const api = baseURL();
  const content =
    input.type === "mcq"
      ? { prompt: input.prompt, multiple: input.multiple ?? false, options: input.options ?? [], explanation: input.explanation ?? "" }
      : {
          prompt: input.prompt,
          languages: input.languages ?? [],
          starter_code: input.starter_code ?? {},
          time_limit_ms: input.time_limit_ms ?? 2000,
          memory_limit_kb: input.memory_limit_kb ?? 262144,
          test_cases: input.test_cases ?? [],
        };

  const headers = await authHeaders();
  try {
    const res = await fetch(`${api}/api/questions`, {
      method: "POST",
      headers,
      body: JSON.stringify({
        type: input.type,
        title: input.title,
        difficulty: input.difficulty,
        default_points: input.default_points,
        tags: input.tags,
        content,
      }),
      cache: "no-store",
    });
    if (!res.ok) {
      const body: { error?: string; fields?: Record<string, string> } = await res.json().catch(() => ({}));
      return { error: body.error ?? "Could not create the question.", fieldErrors: body.fields };
    }
  } catch {
    return { error: "Network error. Please try again." };
  }

  revalidatePath(ROUTES.ADMIN_QUESTION_BANK);
  return { ok: true };
}

export async function archiveQuestionAction(questionId: string): Promise<FormState> {
  const api = baseURL();
  const headers = await authHeaders();
  try {
    const res = await fetch(`${api}/api/questions/${questionId}`, { method: "DELETE", headers, cache: "no-store" });
    if (!res.ok) return { error: "Could not archive the question." };
  } catch {
    return { error: "Network error. Please try again." };
  }
  revalidatePath(ROUTES.ADMIN_QUESTION_BANK);
  return { ok: true };
}
