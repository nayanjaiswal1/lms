"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Star } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";
import { submitPeerFeedbackAction } from "@/lib/workspace/phase5-actions";
import type { PeerFeedbackRow, PersonRef } from "@/lib/workspace/types";

interface RateTeammateRowProps {
  workspaceId: string;
  person: PersonRef;
  existing: PeerFeedbackRow | null;
}

export function RateTeammateRow({ workspaceId, person, existing }: RateTeammateRowProps) {
  const router = useRouter();
  const [rating, setRating] = useState(existing?.rating ?? 0);
  const [comment, setComment] = useState(existing?.comment ?? "");
  const [pending, setPending] = useState(false);

  async function submit() {
    if (rating < 1) {
      toast.error("Pick a rating first.");
      return;
    }
    setPending(true);
    const result = await submitPeerFeedbackAction(workspaceId, { to_user_id: person.user_id, rating, comment: comment || null });
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(existing ? "Rating updated." : "Rating submitted.");
    router.refresh();
  }

  return (
    <div className="flex flex-col gap-2 border-b border-border pb-3 last:border-0">
      <div className="flex items-center justify-between gap-3">
        <p className="text-sm font-medium">{person.name}</p>
        <div aria-label={`Rate ${person.name}`} className="flex gap-0.5" role="radiogroup">
          {[1, 2, 3, 4, 5].map((n) => (
            <button
              aria-label={`${n} star${n === 1 ? "" : "s"}`}
              className="touch-target"
              key={n}
              type="button"
              onClick={() => setRating(n)}
            >
              <Star aria-hidden className={cn("h-5 w-5", n <= rating ? "fill-primary text-primary" : "text-muted-foreground")} />
            </button>
          ))}
        </div>
      </div>
      <Textarea
        maxLength={2000}
        placeholder="Optional comment"
        rows={2}
        value={comment}
        onChange={(e) => setComment(e.target.value)}
      />
      <Button className="w-fit" disabled={pending} size="sm" onClick={submit}>
        {pending ? "Saving…" : existing ? "Update rating" : "Submit rating"}
      </Button>
    </div>
  );
}
