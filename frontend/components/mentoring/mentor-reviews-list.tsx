"use client";

import { parseAsBoolean, useQueryState } from "nuqs";
import { Eye, Star, UserRound } from "lucide-react";
import type { PublicReview } from "@/lib/server/feedback";
import { formatDate } from "@/lib/tickets/format";

interface Props {
  reviews: PublicReview[];
}

// "Recent mentees feedback" card — collapsed by default like the mockup's
// toggle, but only rendered at all when there's at least one written review
// (an empty toggle that reveals nothing isn't worth the click).
export function MentorReviewsList({ reviews }: Props) {
  const [open, setOpen] = useQueryState("reviews", parseAsBoolean.withDefault(false));

  if (reviews.length === 0) return null;

  return (
    <section className="rounded-xl border border-border bg-card p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h2 className="text-lg font-semibold">Recent mentees feedback</h2>
        <button
          className="flex items-center gap-1.5 text-sm font-semibold text-primary hover:underline"
          type="button"
          onClick={() => void setOpen(open ? null : true)}
        >
          <Eye aria-hidden className="h-4 w-4" />
          {open ? "Hide reviews" : "View recent reviews"}
        </button>
      </div>

      {open && (
        <div className="mt-4 flex flex-col gap-3">
          {reviews.map((review) => (
            <article className="rounded-lg border border-border bg-muted/40 p-4" key={review.id}>
              <div className="mb-2 flex items-start justify-between gap-2">
                <div className="flex min-w-0 items-center gap-2.5">
                  <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-secondary text-secondary-foreground">
                    <UserRound aria-hidden className="h-4 w-4" />
                  </span>
                  <div className="min-w-0">
                    <p className="truncate text-sm font-semibold text-foreground">{review.reviewer_name}</p>
                    {review.reviewer_role && (
                      <p className="truncate text-xs text-muted-foreground">{review.reviewer_role}</p>
                    )}
                  </div>
                </div>
                <span aria-hidden className="flex shrink-0 items-center gap-0.5 text-primary">
                  {[1, 2, 3, 4, 5].map((n) => (
                    <Star className="h-3.5 w-3.5" fill={n <= review.rating ? "currentColor" : "none"} key={n} />
                  ))}
                </span>
              </div>
              <p className="text-sm text-muted-foreground">{review.comment}</p>
              <p className="mt-2 text-xs italic text-muted-foreground">Reviewed {formatDate(review.created_at)}</p>
            </article>
          ))}
        </div>
      )}
    </section>
  );
}
