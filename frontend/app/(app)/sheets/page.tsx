import type { Metadata } from "next";
import Link from "next/link";
import { ListChecks } from "lucide-react";

import ROUTES from "@/lib/routes";
import { getPublicSheets, getUserSheets } from "@/lib/server/sheets";
import { DiscoverSheetRow } from "@/components/sheets/discover-sheet-row";
import { SheetCardMenu } from "@/components/sheets/sheet-card-menu";
import { SheetsToolbar } from "@/components/sheets/sheets-toolbar";
import { ProgressRing } from "@/components/shared/progress-ring";

export const metadata: Metadata = { title: "Sheet Tracker" };

// Decorative rotation so cards read as distinct at a glance — cycles by
// position, not tied to any business meaning (unlike primary/ai/success).
const CARD_ACCENTS = [
  { icon: "bg-sheet-accent-1/10 text-sheet-accent-1", ring: "stroke-sheet-accent-1" },
  { icon: "bg-sheet-accent-2/10 text-sheet-accent-2", ring: "stroke-sheet-accent-2" },
  { icon: "bg-sheet-accent-3/10 text-sheet-accent-3", ring: "stroke-sheet-accent-3" },
  { icon: "bg-sheet-accent-4/10 text-sheet-accent-4", ring: "stroke-sheet-accent-4" },
];

export default async function SheetsPage() {
  const [userSheets, publicSheets] = await Promise.all([getUserSheets(), getPublicSheets()]);
  const trackedIds = new Set(userSheets.map((s) => s.id));
  const discoverSheets = publicSheets.filter((s) => !trackedIds.has(s.id));

  return (
    <main className="page-container">
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
          <ListChecks aria-hidden className="empty-state-icon" />
          <p className="text-muted-foreground font-medium">You&apos;re not tracking any sheet yet.</p>
          <p className="text-sm text-muted-foreground">
            Start with a built-in sheet like Striver&apos;s A2Z or NeetCode 150, or create your own.
          </p>
        </div>
      ) : (
        <>
          <div className="flex-between mb-3">
            <h2 className="section-title text-lg">My Sheets</h2>
            <span className="text-sm text-muted-foreground">{userSheets.length} active</span>
          </div>
          <ul className="card-grid">
            {userSheets.map((sheet, i) => {
              const accent = CARD_ACCENTS[i % CARD_ACCENTS.length];
              const pct = sheet.item_count === 0 ? 0 : Math.round((sheet.solved_count / sheet.item_count) * 100);
              return (
                <li className="card-interactive relative flex flex-col gap-4" key={sheet.id}>
                  <Link className="after:absolute after:inset-0 after:content-['']" href={ROUTES.sheet(sheet.slug)}>
                    <div className="flex flex-col gap-1 pr-8">
                      <div className="flex items-center gap-3">
                        <div className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-md ${accent.icon}`}>
                          <ListChecks aria-hidden className="h-5 w-5" />
                        </div>
                        <div className="flex min-w-0 flex-1 items-center gap-2">
                          <span className="truncate text-base font-semibold text-foreground">{sheet.name}</span>
                          {sheet.category && (
                            <span className="badge-muted shrink-0 rounded-sm border px-2 py-0.5 text-xs font-medium">
                              {sheet.category}
                            </span>
                          )}
                        </div>
                      </div>
                      {sheet.description && (
                        <p className="line-clamp-2 pl-12 text-sm leading-snug text-muted-foreground">{sheet.description}</p>
                      )}
                    </div>
                  </Link>

                  <div className="mt-auto flex items-center justify-end gap-2">
                    <ProgressRing pct={pct} size={18} className={accent.ring} />
                    <span className="shrink-0 text-xs text-muted-foreground">
                      {sheet.item_count} question{sheet.item_count === 1 ? "" : "s"}
                    </span>
                  </div>

                  <div className="absolute right-3 top-3 z-dropdown">
                    <SheetCardMenu sheet={sheet} />
                  </div>
                </li>
              );
            })}
          </ul>
        </>
      )}

      {discoverSheets.length > 0 && (
        <div className="mt-8">
          <h2 className="section-title mb-1 text-lg">Discover more sheets</h2>
          <p className="mb-3 text-sm text-muted-foreground">Built-in lists you haven&apos;t started tracking yet.</p>
          <ul className="card-grid">
            {discoverSheets.map((sheet) => (
              <DiscoverSheetRow key={sheet.id} sheet={sheet} />
            ))}
          </ul>
        </div>
      )}
    </main>
  );
}
