"use client";

import { Button } from "@/components/ui/button";
import { useGroupExpandSignal } from "@/components/sheets/group-expand-context";

const LINK_BUTTON_CLASS =
  "h-auto p-0 text-xs font-normal text-muted-foreground hover:bg-transparent hover:text-foreground";

export function GroupExpandToggle() {
  const { expandAll, collapseAll } = useGroupExpandSignal();

  return (
    <div className="inline-flex items-center gap-2">
      <Button className={LINK_BUTTON_CLASS} variant="ghost" onClick={expandAll}>
        Expand all
      </Button>
      <span aria-hidden className="text-xs text-border">
        |
      </span>
      <Button className={LINK_BUTTON_CLASS} variant="ghost" onClick={collapseAll}>
        Collapse all
      </Button>
    </div>
  );
}
