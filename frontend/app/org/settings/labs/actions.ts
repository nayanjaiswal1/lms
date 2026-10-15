"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type { DebugUiMode } from "@/lib/constants";

export interface LabSettings {
  debug_ui: DebugUiMode;
}

export async function saveLabSettingsAction(settings: LabSettings): Promise<{ error?: string }> {
  const result = await apiAction<LabSettings>("PATCH", "/api/admin/labs/settings", settings);
  if (!result.ok) {
    return { error: result.error ?? "Failed to save lab settings." };
  }
  revalidatePath(ROUTES.ORG_SETTINGS_LABS);
  return {};
}
