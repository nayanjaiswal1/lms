"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import { SheetTableRow } from "@/components/sheets/sheet-table-row";
import type { SheetItem } from "@/lib/server/sheets";

export interface ItemGroup {
  label: string;
  items: SheetItem[];
}

interface SheetItemGroupsProps {
  groups: ItemGroup[];
  sheetId: string;
  isOwner: boolean;
}

export function SheetItemGroups({ groups, sheetId, isOwner }: SheetItemGroupsProps) {
  const allLabels = groups.map((g) => g.label);
  const [openGroups, setOpenGroups] = useState<string[]>(allLabels);

  return (
    <div>
      <div className="flex justify-end gap-1 pb-2">
        <Button size="sm" variant="ghost" onClick={() => setOpenGroups(allLabels)}>
          Expand all
        </Button>
        <Button size="sm" variant="ghost" onClick={() => setOpenGroups([])}>
          Collapse all
        </Button>
      </div>

      <Accordion type="multiple" value={openGroups} onValueChange={setOpenGroups}>
        {groups.map((group) => (
          <AccordionItem key={group.label} value={group.label}>
            <AccordionTrigger>
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
                  <SheetTableRow index={index} isOwner={isOwner} item={item} key={item.id} sheetId={sheetId} />
                ))}
              </ul>
            </AccordionContent>
          </AccordionItem>
        ))}
      </Accordion>
    </div>
  );
}
