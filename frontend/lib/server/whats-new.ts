import "server-only";

import { apiGet } from "@/lib/server/api";
import type { WhatsNewEntry } from "@/lib/whats-new";

/** Published entries for the /platform/whats-new admin editor's live preview context. */
export async function getAdminWhatsNewEntries(): Promise<WhatsNewEntry[]> {
  const { entries } = await apiGet<{ entries: WhatsNewEntry[] }>("/api/admin/whats-new");
  return entries;
}
