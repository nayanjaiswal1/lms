"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { requirementGapsAction } from "@/lib/workspace/phase3-actions";
import { useIdempotencyKey } from "@/hooks/use-idempotency-key";

interface GapsPanelProps {
  workspaceId: string;
}

/** Manager+ only AI panel — caller (requirement/page.tsx) already gates
 * rendering by role; this component doesn't re-check since useProjectRole
 * isn't needed once the parent has decided to render it. Cached server-side
 * (workspace_ai_cache), so re-clicking "Check for gaps" is cheap. */
export function GapsPanel({ workspaceId }: GapsPanelProps) {
  const [gaps, setGaps] = useState<string[] | null>(null);
  const [pending, startTransition] = useTransition();
  const withKey = useIdempotencyKey();

  function check() {
    startTransition(async () => {
      const result = await withKey((key) => requirementGapsAction(workspaceId, key));
      if (result.error) {
        toast.error(result.error);
        return;
      }
      setGaps(result.data?.gaps ?? []);
    });
  }

  return (
    <div className="ai-surface flex flex-col gap-3 rounded-md p-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="ai-badge w-fit">AI</span>
        <Button disabled={pending} size="sm" variant="outline" onClick={check}>
          {pending ? "Checking…" : gaps ? "Refresh gaps" : "Check for gaps"}
        </Button>
      </div>
      {gaps && (
        gaps.length === 0 ? (
          <p className="text-sm text-muted-foreground">No obvious gaps found in the current requirement.</p>
        ) : (
          <ul className="flex flex-col gap-1.5 text-sm">
            {gaps.map((gap, i) => (
              <li className="flex items-start gap-2" key={i}>
                <span aria-hidden className="mt-1 h-1 w-1 shrink-0 rounded-full bg-ai" />
                {gap}
              </li>
            ))}
          </ul>
        )
      )}
    </div>
  );
}
