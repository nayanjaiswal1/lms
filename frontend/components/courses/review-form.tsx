"use client";

import { useActionState, useState } from "react";
import { Star } from "lucide-react";
import { Button } from "@/components/ui/button";
import { submitReviewAction } from "@/lib/courses/actions";
import type { ActionResult } from "@/lib/server/api";

interface ReviewFormProps {
  courseId: string;
  initialRating: number | null;
  onSubmitted?: (rating: number) => Promise<void> | void;
}

export function ReviewForm({ courseId, initialRating, onSubmitted }: ReviewFormProps) {
  const [rating, setRating] = useState(initialRating ?? 0);

  async function submit(_prev: ActionResult, formData: FormData): Promise<ActionResult> {
    const courseId = formData.get("course_id") as string;
    const rating = Number(formData.get("rating"));
    const result = await submitReviewAction(courseId, rating);
    if (result.ok) await onSubmitted?.(rating);
    return result;
  }

  const [state, action, isPending] = useActionState<ActionResult, FormData>(submit, {});

  return (
    <form action={action} className="flex flex-col gap-3 border-t border-border pt-6">
      <input name="course_id" type="hidden" value={courseId} />
      <input name="rating" type="hidden" value={rating} />

      <p className="text-sm font-medium">{initialRating ? "Your rating" : "Rate this course"}</p>

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

      {state.error && (
        <p className="text-sm text-destructive" role="alert">{state.error}</p>
      )}

      <Button className="w-fit" disabled={isPending || rating === 0} size="sm" type="submit">
        {isPending ? "Saving…" : initialRating ? "Update rating" : "Submit rating"}
      </Button>
    </form>
  );
}
