import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft, Plus } from "lucide-react";

import ROUTES from "@/lib/routes";
import { getSheetItems, getSheetSettings, getUserSheets } from "@/lib/server/sheets";
import { Button } from "@/components/ui/button";
import { SheetSplitView } from "@/components/sheets/sheet-split-view";
import type { GroupBy } from "@/components/sheets/sheet-table";
import { GroupToggle } from "@/components/sheets/group-toggle";
import { StatusFilterToggle, type StatusFilter } from "@/components/sheets/status-filter-toggle";
import { GroupExpandProvider } from "@/components/sheets/group-expand-context";
import { NotesPanelProvider } from "@/components/sheets/notes-panel-context";
import { GroupExpandToggle } from "@/components/sheets/group-expand-toggle";
import { RevisionSettings } from "@/components/sheets/revision-settings";

export const metadata: Metadata = { title: "Sheet Tracker" };

const VALID_GROUP_BY: GroupBy[] = ["none", "topic", "difficulty"];

interface SheetDetailPageProps {
  params: Promise<{ slug: string }>;
  searchParams: Promise<{ item?: string; group?: string; edit?: string; filter?: string }>;
}

const VALID_STATUS_FILTERS: StatusFilter[] = ["done", "revisit", "starred"];

function sheetHref(slug: string, params: Record<string, string | undefined>): string {
  const qs = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value) qs.set(key, value);
  }
  const query = qs.toString();
  return `${ROUTES.sheet(slug)}${query ? `?${query}` : ""}`;
}

export default async function SheetDetailPage({ params, searchParams }: SheetDetailPageProps) {
  const { slug } = await params;
  const { item, group, edit, filter } = await searchParams;
  const groupBy: GroupBy = VALID_GROUP_BY.includes(group as GroupBy) ? (group as GroupBy) : "none";
  const isAddingItem = item === "new";
  const isEditMode = edit === "1";
  const activeFilters = new Set(
    (filter?.split(",") ?? []).filter((f): f is StatusFilter => VALID_STATUS_FILTERS.includes(f as StatusFilter)),
  );

  const userSheets = await getUserSheets();
  const activeSheet = userSheets.find((s) => s.slug === slug);
  if (!activeSheet) notFound();

  const itemsResponse = await getSheetItems(slug);
  const revisionSettings = await getSheetSettings(itemsResponse.sheet.id);
  const visibleItems =
    activeFilters.size === 0
      ? itemsResponse.items
      : itemsResponse.items.filter(
          (i) =>
            (activeFilters.has("done") && i.status === "done") ||
            (activeFilters.has("revisit") && i.status === "revisit") ||
            (activeFilters.has("starred") && i.is_starred),
        );

  const carryParams = {
    group: groupBy !== "none" ? groupBy : undefined,
    edit: isEditMode ? "1" : undefined,
    filter: activeFilters.size > 0 ? [...activeFilters].join(",") : undefined,
  };
  const baseSheetUrl = sheetHref(slug, carryParams);
  const toggleEditModeHref = sheetHref(slug, { ...carryParams, edit: isEditMode ? undefined : "1" });
  const addItemHref = sheetHref(slug, { ...carryParams, item: "new" });

  const totalCount = itemsResponse.items.length;
  const solvedCount = itemsResponse.items.filter((i) => i.status === "done").length;
  const solvedPct = totalCount > 0 ? Math.round((solvedCount / totalCount) * 100) : 0;

  return (
    <main>
      <Link
        className="mb-4 inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
        href={ROUTES.SHEETS}
      >
        <ArrowLeft aria-hidden className="h-4 w-4" />
        All sheets
      </Link>

      <GroupExpandProvider>
        <NotesPanelProvider>
          <div className="page-header items-start pt-0 pb-6">
            <div>
              <h1 className="page-title">{activeSheet.name}</h1>
              {activeSheet.description && (
                <p className="text-sm text-muted-foreground">{activeSheet.description}</p>
              )}
              {totalCount > 0 && (
                <div className="mt-3 flex max-w-xs items-center gap-3">
                  <div className="progress-track">
                    <div
                      className="progress-fill progress-fill-success"
                      style={{ "--progress": `${solvedPct}%` } as React.CSSProperties}
                    />
                  </div>
                  <span className="shrink-0 text-xs font-medium tabular-nums text-muted-foreground">
                    {solvedCount}/{totalCount} solved
                  </span>
                </div>
              )}
            </div>
            <div className="flex items-center gap-4 pt-1">
              {groupBy !== "none" && <GroupExpandToggle />}
              <RevisionSettings
                baseRevisionDays={revisionSettings.base_revision_days}
                growthScheme={revisionSettings.growth_scheme}
                isEditMode={isEditMode}
                isOwner={activeSheet.role === "owner"}
                sheetId={itemsResponse.sheet.id}
                toggleEditModeHref={toggleEditModeHref}
              />
              <StatusFilterToggle
                activeFilters={activeFilters}
                activeSlug={slug}
                extraParams={{ group: carryParams.group, edit: carryParams.edit }}
              />
              <GroupToggle
                activeSlug={slug}
                extraParams={{ filter: carryParams.filter, edit: carryParams.edit }}
                groupBy={groupBy}
              />
              {activeSheet.role === "owner" && isEditMode && !isAddingItem && (
                <Button asChild size="sm" variant="outline">
                  <Link href={addItemHref}>
                    <Plus aria-hidden className="h-4 w-4" />
                    Add problem
                  </Link>
                </Button>
              )}
            </div>
          </div>
          <SheetSplitView
            cancelAddItemHref={baseSheetUrl}
            groupBy={groupBy}
            isAdding={isAddingItem}
            isEditMode={isEditMode}
            isOwner={activeSheet.role === "owner"}
            items={visibleItems}
            sheetId={itemsResponse.sheet.id}
          />
        </NotesPanelProvider>
      </GroupExpandProvider>
    </main>
  );
}
