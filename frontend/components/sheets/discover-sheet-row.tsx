"use client";

import { useTransition } from "react";
import { toast } from "sonner";
import { ListChecks } from "lucide-react";
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
    <li className="card-base flex flex-col gap-4">
      <div className="flex flex-col gap-1">
        <div className="flex items-center gap-3">
          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-md bg-muted text-muted-foreground">
            <ListChecks aria-hidden className="h-5 w-5" />
          </div>
          <div className="flex min-w-0 flex-1 items-center gap-2">
            <span className="truncate text-base font-semibold text-foreground">{sheet.name}</span>
            {sheet.category && (
              <span className="badge-muted shrink-0 rounded-sm border px-2 py-0.5 text-xs font-medium">
                {sheet.category}
              </span>
            )}
          </div>
        </div>
        {sheet.description && (
          <p className="line-clamp-2 pl-12 text-sm leading-snug text-muted-foreground">{sheet.description}</p>
        )}
      </div>

      <div className="mt-auto flex items-center gap-2">
        <span className="shrink-0 text-xs text-muted-foreground">
          {sheet.item_count} question{sheet.item_count === 1 ? "" : "s"}
        </span>
        <Button className="ml-auto" disabled={isPending} size="sm" variant="outline" onClick={subscribe}>
          {isPending ? "Adding…" : "Track"}
        </Button>
      </div>
    </li>
  );
}
