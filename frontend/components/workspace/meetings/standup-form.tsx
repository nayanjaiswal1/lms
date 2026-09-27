"use client";

import { useState } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { postStandupAction } from "@/lib/workspace/phase3-actions";
import type { Standup } from "@/lib/workspace/types";

interface StandupFormProps {
  workspaceId: string;
  /** Today's own standup, if already posted — prefills for editing (PostStandup upserts). */
  mine: Standup | null;
  onPosted: (standup: Standup) => void;
}

/** Own-standup composer — raw state + a single submit, same convention as
 * the sibling clarify/question-composer.tsx and comments-panel.tsx (short,
 * unvalidated-beyond-length text, no multi-field schema worth a react-hook-form). */
export function StandupForm({ workspaceId, mine, onPosted }: StandupFormProps) {
  const [yesterday, setYesterday] = useState(mine?.yesterday ?? "");
  const [today, setToday] = useState(mine?.today ?? "");
  const [blockers, setBlockers] = useState(mine?.blockers ?? "");
  const [pending, setPending] = useState(false);

  async function submit() {
    if (!yesterday.trim() || !today.trim()) {
      toast.error("Fill in yesterday and today.");
      return;
    }
    setPending(true);
    const result = await postStandupAction(workspaceId, {
      yesterday: yesterday.trim(),
      today: today.trim(),
      blockers: blockers.trim() || undefined,
    });
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    if (result.data) onPosted(result.data);
    toast.success(mine ? "Standup updated." : "Standup posted.");
  }

  return (
    <div className="card-base flex flex-col gap-3">
      <h2 className="text-sm font-medium text-muted-foreground">{mine ? "Update today's standup" : "Post today's standup"}</h2>
      <div className="flex flex-col gap-1.5">
        <label className="text-sm font-medium" htmlFor="standup-yesterday">Yesterday</label>
        <Textarea disabled={pending} id="standup-yesterday" rows={2} value={yesterday} onChange={(e) => setYesterday(e.target.value)} />
      </div>
      <div className="flex flex-col gap-1.5">
        <label className="text-sm font-medium" htmlFor="standup-today">Today</label>
        <Textarea disabled={pending} id="standup-today" rows={2} value={today} onChange={(e) => setToday(e.target.value)} />
      </div>
      <div className="flex flex-col gap-1.5">
        <label className="text-sm font-medium" htmlFor="standup-blockers">Blockers (optional — mention ticket keys like {"ABC-12"})</label>
        <Textarea disabled={pending} id="standup-blockers" rows={2} value={blockers} onChange={(e) => setBlockers(e.target.value)} />
      </div>
      <Button className="w-fit" disabled={pending} onClick={submit}>
        {pending ? "Saving…" : mine ? "Update" : "Post"}
      </Button>
    </div>
  );
}
