"use client";

import { useRef, useState } from "react";
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import { SheetTableRow } from "@/components/sheets/sheet-table-row";
import { useGroupExpandSignal } from "@/components/sheets/group-expand-context";
import type { SheetItem } from "@/lib/server/sheets";

export interface ItemGroup {
  label: string;
  items: SheetItem[];
}

interface SheetItemGroupsProps {
  groups: ItemGroup[];
  sheetId: string;
  isOwner: boolean;
  isEditMode: boolean;
  activeItemId?: string | null;
  onSelectItem?: (itemId: string) => void;
}

export function SheetItemGroups({
  groups,
  sheetId,
  isOwner,
  isEditMode,
  activeItemId,
  onSelectItem,
}: SheetItemGroupsProps) {
  const allLabels = groups.map((g) => g.label);
  const [openGroups, setOpenGroups] = useState<string[]>(allLabels);

  // Expand all / Collapse all live in the sheet toolbar now, not here.
  // Reacting to the shared signal by comparing against the last-handled id
  // during render (rather than in a useEffect) is React's documented
  // effect-free pattern for "adjusting state when an external value changes".
  const { signal } = useGroupExpandSignal();
  const lastSignalId = useRef(0);
  if (signal && signal.id !== lastSignalId.current) {
    lastSignalId.current = signal.id;
    setOpenGroups(signal.type === "expand" ? allLabels : []);
  }

  return (
    <Accordion type="multiple" value={openGroups} onValueChange={setOpenGroups}>
      {groups.map((group) => (
        <AccordionItem key={group.label} value={group.label}>
          <AccordionTrigger className="px-3 py-2.5 text-xs bg-muted/40">
            <span>
              {group.label}{" "}
              <span className="normal-case font-normal tabular-nums text-muted-foreground">
                ({group.items.length})
              </span>
            </span>
          </AccordionTrigger>
          <AccordionContent>
            <ul>
              {group.items.map((item, index) => (
                <SheetTableRow
                  index={index}
                  isActive={item.id === activeItemId}
                  isEditMode={isEditMode}
                  isOwner={isOwner}
                  item={item}
                  key={item.id}
                  sheetId={sheetId}
                  onSelect={onSelectItem}
                />
              ))}
            </ul>
          </AccordionContent>
        </AccordionItem>
      ))}
    </Accordion>
  );
}
