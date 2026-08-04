"use server";

import { redirect } from "next/navigation";

import { apiAction } from "@/lib/server/api";
import { safeNextPath } from "@/lib/utils";
import ROUTES from "@/lib/routes";

export interface AcceptLegalState {
  error?: string;
}

// Accepts every doc_type in docTypes (one POST each — the table is
// append-only per document, there's no batch endpoint) then redirects. Only
// two doc types exist today (terms, privacy), so a loop of two requests is
// simpler than adding a bulk-accept API for it.
export async function acceptLegalDocsAction(
  docTypes: string[],
  next: string | undefined,
  _prev: AcceptLegalState,
): Promise<AcceptLegalState> {
  for (const docType of docTypes) {
    const result = await apiAction("POST", "/api/legal/accept", { doc_type: docType });
    if (result.error) return { error: result.error };
  }
  redirect(safeNextPath(next) ?? ROUTES.DASHBOARD);
}
