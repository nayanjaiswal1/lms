"use client";

import { useActionState, useState } from "react";
import { Star } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { rateMentorAction } from "@/lib/mentoring/actions";
import type { ActionResult } from "@/lib/server/api";

interface MentorRatingFormProps {
  mentorId: string;
  initialRating: number | null;
  initialComment: string | null;
}

export function MentorRatingForm({ mentorId, initialRating, initialComment }: MentorRatingFormProps) {
  const [rating, setRating] = useState(initialRating ?? 0);

  async function submit(_prev: ActionResult, formData: FormData): Promise<ActionResult> {
    const id = formData.get("mentor_id") as string;
    const value = Number(formData.get("rating"));
    const comment = (formData.get("comment") as string).trim();
    return rateMentorAction(id, value, comment || undefined);
  }

  const [state, action, isPending] = useActionState<ActionResult, FormData>(submit, {});

  return (
    <form action={action} className="flex flex-col gap-3">
      <input name="mentor_id" type="hidden" value={mentorId} />
      <input name="rating" type="hidden" value={rating} />

      <p className="text-sm font-medium">{initialRating ? "Your rating" : "Rate this mentor"}</p>

      <div aria-label="Star rating" className="flex items-center gap-1" role="radiogroup">
        {[1, 2, 3, 4, 5].map((n) => (
          <button
            aria-label={`${n} star${n === 1 ? "" : "s"}`}
            aria-pressed={rating >= n}
            className="touch-target text-primary"
            key={n}
            type="button"
            onClick={() => setRating(n)}
          >
            <Star aria-hidden className="h-5 w-5" fill={rating >= n ? "currentColor" : "none"} />
          </button>
        ))}
      </div>

      <Textarea defaultValue={initialComment ?? ""} name="comment" placeholder="Optional comment…" rows={3} />

      {state.error && (
        <p className="text-sm text-destructive" role="alert">{state.error}</p>
      )}
      {state.ok && !state.error && (
        <p className="text-sm text-primary">Saved.</p>
      )}

      <Button className="w-fit" disabled={isPending || rating === 0} size="sm" type="submit">
        {isPending ? "Saving…" : initialRating ? "Update rating" : "Submit rating"}
      </Button>
    </form>
  );
}
