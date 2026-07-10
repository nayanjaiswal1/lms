import type { Metadata } from "next";

import { getPublicSheets, getUserSheets } from "@/lib/server/sheets";
import { SheetTypeSelector, type CreateSheetType } from "@/components/sheets/sheet-type-selector";
import { StartExistingPanel } from "@/components/sheets/start-existing-panel";
import { CombineSheetsPanel } from "@/components/sheets/combine-sheets-panel";
import { CreateCustomPanel } from "@/components/sheets/create-custom-panel";

export const metadata: Metadata = { title: "Create a sheet" };

const VALID_TYPES: CreateSheetType[] = ["existing", "combine", "custom"];

interface NewSheetPageProps {
  searchParams: Promise<{ type?: string }>;
}

export default async function NewSheetPage({ searchParams }: NewSheetPageProps) {
  const { type } = await searchParams;
  const activeType: CreateSheetType = VALID_TYPES.includes(type as CreateSheetType)
    ? (type as CreateSheetType)
    : "custom";

  const [userSheets, publicSheets] = await Promise.all([getUserSheets(), getPublicSheets()]);
  const trackedIds = new Set(userSheets.map((s) => s.id));
  const startableSheets = publicSheets.filter((s) => !trackedIds.has(s.id));

  return (
    <main className="page-container py-6">
      <div className="page-header">
        <div>
          <h1 className="page-title">Create a sheet</h1>
          <p className="text-sm text-muted-foreground">
            Start tracking a built-in list, combine sheets you already track, or build your own from scratch.
          </p>
        </div>
      </div>

      <SheetTypeSelector activeType={activeType} />

      <div className="card-base mt-6 p-6">
        {activeType === "existing" && <StartExistingPanel sheets={startableSheets} />}
        {activeType === "combine" && <CombineSheetsPanel sheets={userSheets} />}
        {activeType === "custom" && <CreateCustomPanel />}
      </div>
    </main>
  );
}
