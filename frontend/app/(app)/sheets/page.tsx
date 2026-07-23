import type { Metadata } from "next";
import Link from "next/link";
import { ListChecks } from "lucide-react";

import ROUTES from "@/lib/routes";
import { getPublicSheets, getUserSheets } from "@/lib/server/sheets";
import { DiscoverSheetRow } from "@/components/sheets/discover-sheet-row";
import { SheetCardMenu } from "@/components/sheets/sheet-card-menu";
import { SheetsToolbar } from "@/components/sheets/sheets-toolbar";

export const metadata: Metadata = { title: "Sheet Tracker" };

export default async function SheetsPage() {
  const [userSheets, publicSheets] = await Promise.all([getUserSheets(), getPublicSheets()]);
  const trackedIds = new Set(userSheets.map((s) => s.id));
  const discoverSheets = publicSheets.filter((s) => !trackedIds.has(s.id));

  return (
    <main>
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
        <ul className="flex flex-col divide-y divide-border rounded-md border border-border">
          {userSheets.map((sheet) => (
            <li className="relative flex items-center gap-3 px-4 py-3" key={sheet.id}>
              <Link className="absolute inset-0 z-raised" href={ROUTES.sheet(sheet.slug)}>
                <span className="sr-only">Open {sheet.name}</span>
              </Link>
              <div className="min-w-0">
                <h2 className="truncate font-semibold text-foreground">{sheet.name}</h2>
                {sheet.description && (
                  <p className="truncate text-sm text-muted-foreground">{sheet.description}</p>
                )}
              </div>
              <span className="shrink-0 text-xs text-muted-foreground">
                {sheet.item_count} question{sheet.item_count === 1 ? "" : "s"}
              </span>
              <div className="relative z-dropdown ml-auto shrink-0">
                <SheetCardMenu sheet={sheet} />
              </div>
            </li>
          ))}
        </ul>
      )}

      {discoverSheets.length > 0 && (
        <div className="mt-8">
          <h2 className="section-title mb-1 text-lg">Discover more sheets</h2>
          <p className="mb-3 text-sm text-muted-foreground">Built-in lists you haven&apos;t started tracking yet.</p>
          <ul className="flex flex-col divide-y divide-border rounded-md border border-border">
            {discoverSheets.map((sheet) => (
              <DiscoverSheetRow key={sheet.id} sheet={sheet} />
            ))}
          </ul>
        </div>
      )}
    </main>
  );
}
