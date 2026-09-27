"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Sparkles } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { suggestAssigneesAction } from "@/lib/workspace/phase5-actions";
import type { AssigneeSuggestion } from "@/lib/workspace/types";

interface SuggestAssigneesButtonProps {
  workspaceId: string;
  itemId: string;
  onAssign: (userId: string) => void;
}

/** AI-suggested candidates for this item (contract-phase5.md 5c, D20 — never
 * cached, always a fresh live-WIP read). Suggest-only: "Assign" still goes
 * through the normal setAssigneesAction path via the caller's onAssign. */
export function SuggestAssigneesButton({ workspaceId, itemId, onAssign }: SuggestAssigneesButtonProps) {
  const [suggestions, setSuggestions] = useState<AssigneeSuggestion[] | null>(null);
  const [pending, startTransition] = useTransition();

  function suggest() {
    startTransition(async () => {
      const result = await suggestAssigneesAction(workspaceId, itemId);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      setSuggestions(result.data ?? []);
    });
  }

  return (
    <Popover onOpenChange={(open) => open && !suggestions && suggest()}>
      <PopoverTrigger asChild>
        <Button aria-label="Suggest assignees (AI)" className="text-ai" size="icon" variant="ghost">
          <Sparkles aria-hidden className="h-4 w-4" />
        </Button>
      </PopoverTrigger>
      <PopoverContent align="end" className="ai-surface w-72">
        <p className="ai-badge mb-2 w-fit">AI suggestion</p>
        {pending && <p className="text-sm text-muted-foreground">Thinking…</p>}
        {!pending && suggestions?.length === 0 && <p className="text-sm text-muted-foreground">No candidates found.</p>}
        {!pending && suggestions?.map((s) => (
          <div className="flex items-center justify-between gap-2 border-b border-border py-2 last:border-0" key={s.person.user_id}>
            <div className="min-w-0">
              <p className="truncate text-sm font-medium">{s.person.name} <span className="text-xs text-muted-foreground">· WIP {s.wip}</span></p>
              <p className="text-xs text-muted-foreground">{s.reason}</p>
            </div>
            <Button size="sm" variant="outline" onClick={() => onAssign(s.person.user_id)}>
              Assign
            </Button>
          </div>
        ))}
      </PopoverContent>
    </Popover>
  );
}
