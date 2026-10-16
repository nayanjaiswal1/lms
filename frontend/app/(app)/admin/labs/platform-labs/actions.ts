"use server";

import { apiAction } from "@/lib/server/api";

export interface LabsetImportResult {
  runtime_id: string;
  recipes: number;
  published: number;
  bundles_uploaded: number;
}

export async function importLabsetAction(): Promise<{ result?: LabsetImportResult; error?: string }> {
  const res = await apiAction<LabsetImportResult>("POST", "/api/admin/lab-authoring/labset/import");
  if (!res.ok) return { error: res.error ?? "Labset import failed." };
  return { result: res.data };
}
