import { apiGet } from "@/lib/server/api";
import type { LibraryItemPage } from "@/lib/library/types";

// Server Component read for app/(app)/library/page.tsx's initial render —
// interactive re-search from there on goes through listLibraryItemsAction
// (lib/library/actions.ts), same split as every other list+search page here.
export async function getLibraryItems(): Promise<LibraryItemPage> {
  return apiGet<LibraryItemPage>("/api/library");
}
