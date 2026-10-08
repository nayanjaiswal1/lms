"use client";

import { useCallback, useMemo } from "react";
import "@/vendor/notion-table/notion-table";
import type { CellChangeDetail, NotionTable } from "@/vendor/notion-table/notion-table";
import { updateProgressAction, updateProgressStarredAction } from "@/lib/sheets/actions";
import { GRID_COLUMNS, STARRED_LABEL, STATUS_BY_LABEL, toGridRows, type GridRow } from "@/lib/sheets/grid";
import type { SheetItem } from "@/lib/server/sheets";

interface SheetGridTableProps {
  sheetId: string;
  items: SheetItem[];
}

export default function SheetGridTable({ sheetId, items }: SheetGridTableProps) {
  // The element edits `rows` in place, so the array must stay stable across renders.
  const rows = useMemo(() => toGridRows(items), [items]);

  const bind = useCallback(
    (el: NotionTable | null) => {
      if (!el) return;
      const onCellChange = (e: CustomEvent<CellChangeDetail>) => {
        const { row, key, value } = e.detail;
        const { topicTag } = row as GridRow;
        if (key === "status" && STATUS_BY_LABEL[String(value)]) {
          void updateProgressAction(topicTag, STATUS_BY_LABEL[String(value)], sheetId);
        } else if (key === "starred") {
          void updateProgressStarredAction(topicTag, value === STARRED_LABEL);
        }
      };
      const ac = new AbortController();
      el.addEventListener("cell-change", onCellChange, { signal: ac.signal });
      return () => ac.abort();
    },
    [sheetId],
  );

  return <notion-table readonly aria-label="Sheet problems" columns={GRID_COLUMNS} ref={bind} rows={rows} />;
}
