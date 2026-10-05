"use client";

import { useCallback, useMemo } from "react";
import "@/vendor/notion-table/notion-table";
import type { NotionTable, RowClickDetail } from "@/vendor/notion-table/notion-table";
import { GRID_COLUMNS, toGridRows, type GridRow } from "@/lib/sheets/grid";
import type { SheetItem } from "@/lib/server/sheets";

interface SheetGridTableProps {
  items: SheetItem[];
}

export default function SheetGridTable({ items }: SheetGridTableProps) {
  // The element edits `rows` in place, so the array must stay stable across renders.
  const rows = useMemo(() => toGridRows(items), [items]);

  const bind = useCallback((el: NotionTable | null) => {
    if (!el) return;
    const onRowClick = (e: CustomEvent<RowClickDetail>) => {
      const { url } = e.detail.row as GridRow;
      if (url) window.open(url, "_blank", "noopener,noreferrer");
    };
    const ac = new AbortController();
    el.addEventListener("row-click", onRowClick, { signal: ac.signal });
    return () => ac.abort();
  }, []);

  return <notion-table readonly aria-label="Sheet problems" columns={GRID_COLUMNS} ref={bind} rows={rows} />;
}
