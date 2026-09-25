"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import type { Category } from "@/lib/assessments/types";
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
  category_id?: string | null;
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

  const result = await apiAction("POST", "/api/questions", {
    type: input.type,
    title: input.title,
    difficulty: input.difficulty,
    default_points: input.default_points,
    tags: input.tags,
    category_id: input.category_id ?? null,
    content,
  });
  if (!result.ok) {
    return { error: result.error ?? "Could not create the question.", fieldErrors: result.fieldErrors };
  }

  revalidatePath(ROUTES.QUESTION_BANK);
  return { ok: true };
}

export async function createCategoryAction(name: string): Promise<ActionResult<Category>> {
  const result = await apiAction<Category>("POST", "/api/categories", { name });
  if (result.ok) revalidatePath(ROUTES.QUESTION_BANK);
  return result;
}

export async function archiveQuestionAction(questionId: string): Promise<FormState> {
  const result = await apiAction("DELETE", `/api/questions/${questionId}`);
  if (!result.ok) return { error: result.error ?? "Could not archive the question." };
  revalidatePath(ROUTES.QUESTION_BANK);
  return { ok: true };
}
