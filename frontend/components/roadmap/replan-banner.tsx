"use client";

import { useState } from "react";
import { toast } from "sonner";
import { CalendarClock } from "lucide-react";
import { Button } from "@/components/ui/button";
import { replanRoadmapAction } from "@/lib/roadmap/actions";
import type { Roadmap } from "@/lib/server/roadmap";

const COPY = {
  title: "You're behind schedule",
  button: "Re-plan remaining work",
  pending: "Re-planning…",
  success: "Roadmap re-planned around your pace.",
  failure: "Couldn't re-plan this roadmap.",
} as const;

export function ReplanBanner({ roadmap }: { roadmap: Roadmap }) {
  const [pending, setPending] = useState(false);

  async function handleClick() {
    setPending(true);
    const result = await replanRoadmapAction(roadmap.id);
    setPending(false);
    if (!result.ok) {
      toast.error(result.error ?? COPY.failure);
      return;
    }
    toast.success(COPY.success);
  }

  return (
    <div
      className="flex flex-col gap-3 rounded-md border border-warning/40 bg-warning/10 p-4 sm:flex-row sm:items-center sm:justify-between"
      role="status"
    >
      <div className="flex items-start gap-3">
        <CalendarClock aria-hidden className="mt-0.5 h-5 w-5 text-warning" />
        <div>
          <p className="font-medium text-foreground">{COPY.title}</p>
          <p className="text-sm text-muted-foreground">
            {Math.round(roadmap.progress_pct)}% done, {Math.round(roadmap.expected_pct)}% of the timeline used.
          </p>
        </div>
      </div>
      <Button className="touch-target" disabled={pending} size="sm" onClick={handleClick}>
        {pending ? COPY.pending : COPY.button}
      </Button>
    </div>
  );
}
