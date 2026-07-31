"use client";

import * as React from "react";
import { QuickCreateSlot } from "@/app/(app)/calendar/quick-create-slot";
import { EnhancedQuickCreate } from "@/app/(app)/calendar/enhanced-quick-create";
import { Lightbulb } from "lucide-react";
import type { CalendarEventPriority } from "@/lib/calendar/types";

interface QuickCreateAdapterProps {
  defaultStart: Date;
  defaultEnd: Date;
  onCreate: (
    title: string,
    start: Date,
    end: Date,
    isTask: boolean,
    notes?: string,
    priority?: CalendarEventPriority,
  ) => void;
  onCancel: () => void;
  useEnhanced?: boolean;
}

export function QuickCreateAdapter({
  defaultStart,
  defaultEnd,
  onCreate,
  onCancel,
  useEnhanced = true,
}: QuickCreateAdapterProps) {
  const [mode, setMode] = React.useState<"quick" | "full">(useEnhanced ? "full" : "quick");

  if (!useEnhanced || mode === "quick") {
    return (
      <div className="space-y-3">
        <QuickCreateSlot
          defaultStart={defaultStart}
          defaultEnd={defaultEnd}
          onCreate={onCreate}
          onCancel={onCancel}
        />
        {useEnhanced && (
          <button
            onClick={() => setMode("full")}
            className="flex w-full items-center justify-center gap-1.5 rounded-md bg-muted/50 px-3 py-2 text-xs text-muted-foreground transition-colors hover:bg-muted"
          >
            <Lightbulb className="h-3.5 w-3.5" />
            Show advanced options
          </button>
        )}
      </div>
    );
  }

  return (
    <EnhancedQuickCreate
      defaultStart={defaultStart}
      defaultEnd={defaultEnd}
      onCreate={onCreate}
      onCancel={onCancel}
    />
  );
}
