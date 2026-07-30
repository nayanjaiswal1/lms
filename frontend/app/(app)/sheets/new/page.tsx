import type { Metadata } from "next";

import { getPublicSheets, getSheetItems, getUserSheets, type SheetItem } from "@/lib/server/sheets";
import { TrackOrCombinePanel } from "@/components/sheets/track-or-combine-panel";

export const metadata: Metadata = { title: "Create a sheet" };

export default async function NewSheetPage() {
  const [userSheets, publicSheets] = await Promise.all([getUserSheets(), getPublicSheets()]);
  const trackedIds = new Set(userSheets.map((s) => s.id));
  const startableSheets = publicSheets.filter((s) => !trackedIds.has(s.id));

  const allSheets = [...userSheets, ...startableSheets];
  const itemsBySheetId: Record<string, SheetItem[]> = {};
  const itemsResults = await Promise.all(allSheets.map((s) => getSheetItems(s.slug)));
  itemsResults.forEach((result, i) => {
    itemsBySheetId[allSheets[i].id] = result.items;
  });

  return (
    <main className="page-container-sm">
      <div className="page-header">
        <div>
          <h1 className="page-title">Create a sheet</h1>
          <p className="text-sm text-muted-foreground">
            Track built-in lists, combine 2+ into one deduped sheet, or leave every sheet unchecked to build your
            own from scratch.
          </p>
        </div>
      </div>

      <TrackOrCombinePanel
        itemsBySheetId={itemsBySheetId}
        startableSheets={startableSheets}
        userSheets={userSheets}
      />
    </main>
  );
}
