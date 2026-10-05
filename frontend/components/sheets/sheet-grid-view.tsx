"use client";

import dynamic from "next/dynamic";
import { Skeleton } from "@/components/ui/skeleton";
import type { SheetItem } from "@/lib/server/sheets";

const SheetGridTable = dynamic(() => import("@/components/sheets/sheet-grid-table"), {
  ssr: false,
  loading: () => <Skeleton className="h-96 w-full" />,
});

interface SheetGridViewProps {
  items: SheetItem[];
}

export function SheetGridView({ items }: SheetGridViewProps) {
  if (items.length === 0) {
    return <p className="py-6 text-center text-sm text-muted-foreground">This sheet has no problems yet.</p>;
  }
  return (
    <div className="h-[calc(100dvh-12rem)] min-h-[420px] overflow-y-auto">
      <SheetGridTable items={items} />
    </div>
  );
}
