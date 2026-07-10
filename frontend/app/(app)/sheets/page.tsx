import type { Metadata } from "next";
import { ListChecks } from "lucide-react";

import ROUTES from "@/lib/routes";
import { getSheetItems, getUserSheets } from "@/lib/server/sheets";
import { SheetTabs } from "@/components/sheets/sheet-tabs";
import { SheetsToolbar } from "@/components/sheets/sheets-toolbar";
import { SheetTable, type GroupBy } from "@/components/sheets/sheet-table";
import { GroupToggle } from "@/components/sheets/group-toggle";

export const metadata: Metadata = { title: "Sheet Tracker" };

const VALID_GROUP_BY: GroupBy[] = ["none", "topic", "difficulty"];

interface SheetsPageProps {
  searchParams: Promise<{ sheet?: string; item?: string; group?: string }>;
}

export default async function SheetsPage({ searchParams }: SheetsPageProps) {
  const { sheet: sheetParam, item, group } = await searchParams;
  const groupBy: GroupBy = VALID_GROUP_BY.includes(group as GroupBy) ? (group as GroupBy) : "none";
  const isAddingItem = item === "new";

  const userSheets = await getUserSheets();

  const activeSlug = sheetParam ?? userSheets[0]?.slug;
  const activeSheet = userSheets.find((s) => s.slug === activeSlug);
  const itemsResponse = activeSlug ? await getSheetItems(activeSlug) : null;

  const baseSheetUrl = `${ROUTES.SHEETS}?sheet=${encodeURIComponent(activeSlug ?? "")}${
    groupBy !== "none" ? `&group=${groupBy}` : ""
  }`;

  return (
    <main className="page-container py-6">
      <div className="page-header">
        <div>
          <h1 className="page-title">Sheet Tracker</h1>
          <p className="text-sm text-muted-foreground">
            Create your own problem list or start with a built-in one, and track your progress.
          </p>
        </div>
        <SheetsToolbar />
      </div>

      {userSheets.length === 0 ? (
        <div className="empty-state">
          <ListChecks aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="text-muted-foreground font-medium">You&apos;re not tracking any sheet yet.</p>
          <p className="text-sm text-muted-foreground">
            Start with a built-in sheet like Striver&apos;s A2Z or NeetCode 150, or create your own.
          </p>
        </div>
      ) : (
        <>
          <SheetTabs activeSlug={activeSlug} sheets={userSheets} />
          {itemsResponse && activeSheet && (
            <>
              <div className="flex justify-end mb-3">
                <GroupToggle activeSlug={activeSlug ?? ""} groupBy={groupBy} />
              </div>
              <SheetTable
                addItemHref={`${baseSheetUrl}&item=new`}
                cancelAddItemHref={baseSheetUrl}
                groupBy={groupBy}
                isAdding={isAddingItem}
                isOwner={activeSheet.role === "owner"}
                items={itemsResponse.items}
                sheetId={itemsResponse.sheet.id}
              />
            </>
          )}
        </>
      )}
    </main>
  );
}
