"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";
import { Button } from "@/components/ui/button";
import ROUTES from "@/lib/routes";
import { subscribeSheetAction } from "@/lib/sheets/actions";
import type { Sheet } from "@/lib/server/sheets";

interface StartExistingPanelProps {
  sheets: Sheet[];
}

export function StartExistingPanel({ sheets }: StartExistingPanelProps) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  function start(sheet: Sheet) {
    startTransition(async () => {
      const result = await subscribeSheetAction(sheet.id);
      if (result.ok) router.push(`${ROUTES.SHEETS}?sheet=${encodeURIComponent(sheet.slug)}`);
    });
  }

  if (sheets.length === 0) {
    return (
      <p className="text-sm text-muted-foreground py-4">
        You&apos;re already tracking every built-in sheet.
      </p>
    );
  }

  return (
    <ul className="flex flex-col divide-y divide-border">
      {sheets.map((sheet) => (
        <li className="flex items-center justify-between gap-3 py-3" key={sheet.id}>
          <div className="min-w-0">
            <p className="text-sm font-medium text-foreground truncate">{sheet.name}</p>
            {sheet.description && (
              <p className="text-xs text-muted-foreground truncate">{sheet.description}</p>
            )}
          </div>
          <Button disabled={isPending} size="sm" variant="outline" onClick={() => start(sheet)}>
            Start tracking
          </Button>
        </li>
      ))}
    </ul>
  );
}
