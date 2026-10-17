import type { Metadata } from "next";

import ROUTES from "@/lib/routes";
import { getPublicSheets, getSheetItems, getUserSheets, type SheetItem } from "@/lib/server/sheets";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { TrackOrCombinePanel } from "@/components/sheets/track-or-combine-panel";
import { PageHeader } from "@/components/shared/page-header";

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
      <Breadcrumb items={[{ label: "Sheets", href: ROUTES.SHEETS }, { label: "New" }]} />
      <PageHeader title="Create a sheet" description="Track built-in lists, combine 2+ into one deduped sheet, or leave every sheet unchecked to build your own from scratch." />

      <TrackOrCombinePanel
        itemsBySheetId={itemsBySheetId}
        startableSheets={startableSheets}
        userSheets={userSheets}
      />
    </main>
  );
}
