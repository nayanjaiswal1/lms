"use client";

import { useActionState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import ROUTES from "@/lib/routes";
import {
  addSheetItemAction,
  combineSheetsAction,
  createSheetAction,
  subscribeSheetAction,
} from "@/lib/sheets/actions";
import type { Sheet, SheetItem, UserSheetSummary } from "@/lib/server/sheets";
import { useSheetBuilder } from "@/lib/sheets/use-sheet-builder";
import { AddCustomQuestionRow } from "@/components/sheets/add-custom-question-row";
import { SheetPreviewTable } from "@/components/sheets/sheet-preview-table";

interface TrackOrCombinePanelProps {
  startableSheets: Sheet[];
  userSheets: UserSheetSummary[];
  itemsBySheetId: Record<string, SheetItem[]>;
}

interface State {
  error?: string;
}

export function TrackOrCombinePanel({ startableSheets, userSheets, itemsBySheetId }: TrackOrCombinePanelProps) {
  const router = useRouter();
  const trackedIds = new Set(userSheets.map((s) => s.id));
  const allSheets: Sheet[] = [...userSheets, ...startableSheets];

  const {
    selectedSheets,
    excludedTopics,
    customItems,
    rows,
    toggleSelected,
    toggleExcluded,
    addCustomItem,
    addCustomItems,
    removeCustomItem,
  } = useSheetBuilder(allSheets, itemsBySheetId);

  const [state, formAction, pending] = useActionState<State | null, FormData>(async (_prev, fd) => {
    const sheetIds = fd.getAll("sheet_ids") as string[];
    const name = (fd.get("name") as string)?.trim() ?? "";

    async function addCustomItemsTo(sheetId: string): Promise<string | undefined> {
      for (const item of customItems) {
        const result = await addSheetItemAction(sheetId, {
          title: item.title,
          category: item.category,
          difficulty: item.difficulty,
        });
        if (!result.ok) return result.error;
      }
      return undefined;
    }

    if (sheetIds.length === 0) {
      if (!name) return { error: "Sheet name is required." };
      const description = (fd.get("description") as string)?.trim();
      const category = (fd.get("category") as string)?.trim();
      const result = await createSheetAction({
        name,
        description: description || undefined,
        category: category || undefined,
      });
      if (!result.ok) return { error: result.error };
      if (result.data) {
        const addError = await addCustomItemsTo(result.data.id);
        if (addError) return { error: addError };
        router.push(ROUTES.sheet(result.data.slug));
      }
      return null;
    }

    const needsOwnedCopy = excludedTopics.length > 0 || customItems.length > 0;

    if (!needsOwnedCopy) {
      for (const id of sheetIds) {
        if (trackedIds.has(id)) continue;
        const result = await subscribeSheetAction(id);
        if (!result.ok) return { error: result.error };
      }

      if (sheetIds.length === 1) {
        const sheet = allSheets.find((s) => s.id === sheetIds[0]);
        router.push(ROUTES.sheet(sheet?.slug ?? ""));
        return null;
      }
    }

    if (!name) return { error: "Sheet name is required to combine multiple sheets." };

    const result = await combineSheetsAction({
      name,
      sheet_ids: sheetIds,
      exclude_topic_tags: excludedTopics.length > 0 ? excludedTopics : undefined,
    });
    if (!result.ok) return { error: result.error };
    if (result.data) {
      const addError = await addCustomItemsTo(result.data.id);
      if (addError) return { error: addError };
      router.push(ROUTES.sheet(result.data.slug));
    }
    return null;
  }, null);

  return (
    <>
      <section className="card-base p-6">
        <h2 className="section-title mb-1 text-lg">Track, combine, or create custom</h2>
        <form action={formAction} className="form-stack">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="sheet-name">Sheet name</Label>
            <Input
              disabled={pending}
              id="sheet-name"
              name="name"
              placeholder="My DSA Revision List"
            />
          </div>

          {allSheets.length > 0 && (
            <div className="flex flex-col gap-1.5">
              <Label>Sheets</Label>
              <ul className="flex flex-col divide-y divide-border rounded-md border border-border">
                {allSheets.map((sheet) => (
                  <li className="flex items-center gap-3 px-3 py-2.5" key={sheet.id}>
                    <Checkbox
                      disabled={pending}
                      id={`sheet-${sheet.id}`}
                      name="sheet_ids"
                      value={sheet.id}
                      onCheckedChange={(checked) => toggleSelected(sheet.id, checked === true)}
                    />
                    <Label className="flex-1 cursor-pointer font-normal" htmlFor={`sheet-${sheet.id}`}>
                      {sheet.name}
                    </Label>
                    <span className="text-xs text-muted-foreground">
                      {sheet.item_count} question{sheet.item_count === 1 ? "" : "s"}
                    </span>
                  </li>
                ))}
              </ul>
              <p className="text-xs text-muted-foreground">
                Check none for a blank sheet, one to track it, or two or more to combine them into a new deduped
                sheet.
              </p>
            </div>
          )}

          <AddCustomQuestionRow onAddCustom={addCustomItem} onAddCustomBulk={addCustomItems} />

          <details>
            <summary className="cursor-pointer text-sm text-muted-foreground select-none">
              Category & description (used only when creating a blank sheet)
            </summary>
            <div className="form-stack mt-3">
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="sheet-category">Category</Label>
                <Input disabled={pending} id="sheet-category" name="category" placeholder="DSA" />
              </div>
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="sheet-description">Description</Label>
                <Textarea disabled={pending} id="sheet-description" name="description" rows={3} />
              </div>
            </div>
          </details>

          {state?.error && <p className="text-sm text-destructive">{state.error}</p>}
          <div>
            <Button disabled={pending} type="submit">
              {pending ? "Submitting…" : "Continue"}
            </Button>
          </div>
        </form>
      </section>

      {(selectedSheets.length > 0 || customItems.length > 0) && (
        <SheetPreviewTable
          excludedTopics={excludedTopics}
          rows={rows}
          onRemoveCustom={removeCustomItem}
          onToggleExclude={toggleExcluded}
        />
      )}
    </>
  );
}
