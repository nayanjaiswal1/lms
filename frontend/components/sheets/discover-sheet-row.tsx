"use client";

import { useTransition } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { subscribeSheetAction } from "@/lib/sheets/actions";
import type { Sheet } from "@/lib/server/sheets";

interface DiscoverSheetRowProps {
  sheet: Sheet;
}

export function DiscoverSheetRow({ sheet }: DiscoverSheetRowProps) {
  const [isPending, startTransition] = useTransition();

  function subscribe() {
    startTransition(async () => {
      const result = await subscribeSheetAction(sheet.id);
      if (!result.ok) toast.error(result.error ?? "Couldn't track this sheet.");
      else toast.success(`Tracking ${sheet.name}.`);
    });
  }

  return (
    <li className="flex items-center gap-3 px-4 py-3">
      <div className="min-w-0">
        <h3 className="truncate font-medium text-foreground">{sheet.name}</h3>
        {sheet.description && <p className="truncate text-sm text-muted-foreground">{sheet.description}</p>}
      </div>
      <span className="shrink-0 text-xs text-muted-foreground">
        {sheet.item_count} question{sheet.item_count === 1 ? "" : "s"}
      </span>
      <Button className="ml-auto shrink-0" disabled={isPending} size="sm" variant="outline" onClick={subscribe}>
        {isPending ? "Adding…" : "Track"}
      </Button>
    </li>
  );
}
