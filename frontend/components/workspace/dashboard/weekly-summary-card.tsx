"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Sparkles } from "lucide-react";

import { Button } from "@/components/ui/button";
import { getWeeklySummaryAction } from "@/lib/workspace/phase5-actions";
import { useIdempotencyKey } from "@/hooks/use-idempotency-key";
import type { WeeklySummary } from "@/lib/workspace/types";

function Section({ title, items }: { title: string; items: string[] }) {
  if (items.length === 0) return null;
  return (
    <div>
      <p className="text-xs font-medium text-muted-foreground">{title}</p>
      <ul className="list-inside list-disc text-sm">
        {items.map((line, i) => <li key={i}>{line}</li>)}
      </ul>
    </div>
  );
}

/** Manager+ only (contract-phase5.md 5c/dashboard). Cached per ISO week;
 * "Regenerate" is capped server-side (SummaryRegenPerDay/day). */
export function WeeklySummaryCard({ workspaceId, initial }: { workspaceId: string; initial: WeeklySummary | null }) {
  const [summary, setSummary] = useState(initial);
  const [pending, startTransition] = useTransition();
  const withKey = useIdempotencyKey();

  function regenerate() {
    startTransition(async () => {
      const result = await withKey((key) => getWeeklySummaryAction(workspaceId, true, key));
      if (result.error) {
        toast.error(result.error);
        return;
      }
      setSummary(result.data ?? null);
    });
  }

  function load() {
    startTransition(async () => {
      const result = await withKey((key) => getWeeklySummaryAction(workspaceId, false, key));
      if (result.error) {
        toast.error(result.error);
        return;
      }
      setSummary(result.data ?? null);
    });
  }

  return (
    <div className="ai-surface flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <p className="ai-badge w-fit">AI weekly summary</p>
        <Button disabled={pending} size="sm" variant="outline" onClick={summary ? regenerate : load}>
          <Sparkles aria-hidden className="mr-1.5 h-3.5 w-3.5" />
          {pending ? "Thinking…" : summary ? "Regenerate (max 3/day)" : "Generate"}
        </Button>
      </div>
      {summary ? (
        <div className="flex flex-col gap-2">
          <Section items={summary.shipped} title="Shipped" />
          <Section items={summary.risks} title="Risks" />
          <Section items={summary.needs_help} title="Needs help" />
        </div>
      ) : (
        !pending && <p className="text-sm text-muted-foreground">No summary generated for this week yet.</p>
      )}
    </div>
  );
}
