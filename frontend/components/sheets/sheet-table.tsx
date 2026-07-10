import Link from "next/link";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import type { SheetItem } from "@/lib/server/sheets";
import { SheetTableRow } from "@/components/sheets/sheet-table-row";
import { SheetItemGroups, type ItemGroup } from "@/components/sheets/sheet-item-groups";
import { AddItemInlineRow } from "@/components/sheets/add-item-inline-row";

export type GroupBy = "none" | "topic" | "difficulty";

interface SheetTableProps {
  sheetId: string;
  items: SheetItem[];
  isOwner: boolean;
  groupBy: GroupBy;
  isAdding: boolean;
  addItemHref: string;
  cancelAddItemHref: string;
}

const DIFFICULTY_ORDER = ["easy", "medium", "hard"] as const;
const DIFFICULTY_LABEL: Record<string, string> = { easy: "Easy", medium: "Medium", hard: "Hard" };
const UNSPECIFIED = "Unspecified";

function groupItems(items: SheetItem[], groupBy: GroupBy): ItemGroup[] {
  const groups = new Map<string, SheetItem[]>();
  for (const item of items) {
    const key = groupBy === "topic" ? item.category ?? UNSPECIFIED : item.difficulty ?? UNSPECIFIED;
    const bucket = groups.get(key);
    if (bucket) bucket.push(item);
    else groups.set(key, [item]);
  }

  if (groupBy === "difficulty") {
    const orderedKeys = [...DIFFICULTY_ORDER, UNSPECIFIED];
    return orderedKeys
      .filter((key) => groups.has(key))
      .map((key) => ({ label: DIFFICULTY_LABEL[key] ?? key, items: groups.get(key) ?? [] }));
  }

  return Array.from(groups.entries()).map(([label, groupItems]) => ({ label, items: groupItems }));
}

export function SheetTable({
  sheetId,
  items,
  isOwner,
  groupBy,
  isAdding,
  addItemHref,
  cancelAddItemHref,
}: SheetTableProps) {
  return (
    <div className="table-responsive">
      {items.length === 0 ? (
        <p className="text-sm text-muted-foreground py-6 text-center">
          {isOwner ? "No problems yet — add your first one." : "This sheet has no problems yet."}
        </p>
      ) : groupBy === "none" ? (
        <ul>
          {items.map((item, index) => (
            <SheetTableRow index={index} isOwner={isOwner} item={item} key={item.id} sheetId={sheetId} />
          ))}
        </ul>
      ) : (
        <SheetItemGroups groups={groupItems(items, groupBy)} isOwner={isOwner} sheetId={sheetId} />
      )}

      {isOwner &&
        (isAdding ? (
          <AddItemInlineRow cancelHref={cancelAddItemHref} sheetId={sheetId} />
        ) : (
          <Button asChild className="mt-3" size="sm" variant="outline">
            <Link href={addItemHref}>
              <Plus aria-hidden className="h-4 w-4" />
              Add problem
            </Link>
          </Button>
        ))}
    </div>
  );
}
