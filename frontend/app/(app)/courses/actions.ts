"use server";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";

export interface SnippetResult {
  exit_ok: boolean;
  stdout: string;
  stderr: string;
}

// Runs a standalone lesson code snippet through the backend Piston executor.
// No lab session involved — see POST /api/labs/run.
export async function runSnippetAction(
  language: string,
  code: string,
): Promise<ActionResult<SnippetResult>> {
  return apiAction<SnippetResult>("POST", "/api/labs/run", { language, code });
}
