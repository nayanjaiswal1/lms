"use client";

import { Button } from "@/components/ui/button";
import { parseAsBoolean, useQueryState } from "nuqs";
import { ChevronDown, Quote } from "lucide-react";
import { StarRating } from "@/components/mentoring/star-rating";
import type { PublicReview } from "@/lib/server/feedback";
import { formatDate } from "@/lib/tickets/format";
import { cn } from "@/lib/utils";

const PREVIEW_COUNT = 2;

interface Props {
  reviews: PublicReview[];
}

// "Recent reviews" card — the first couple are always visible so the page
// scans without a click; the rest sit behind a URL-backed toggle. Not
// rendered at all without a written review (an empty card isn't worth the space).
export function MentorReviewsList({ reviews }: Props) {
  const [open, setOpen] = useQueryState("reviews", parseAsBoolean.withDefault(false));

  if (reviews.length === 0) return null;

  const shown = open ? reviews : reviews.slice(0, PREVIEW_COUNT);
  const hiddenCount = reviews.length - PREVIEW_COUNT;

  return (
    <section aria-labelledby="mentor-reviews-title" className="card-raised flex flex-col gap-4">
      <h2 className="subsection-title" id="mentor-reviews-title">
        Recent reviews
      </h2>

      <ul className="flex flex-col divide-y divide-border">
        {shown.map((review) => (
          <li className="flex flex-col gap-2 py-4 first:pt-0 last:pb-0" key={review.id}>
            <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
              <StarRating size="sm" value={review.rating} />
              <span className="sr-only">{review.rating} out of 5</span>
              <time className="text-xs text-muted-foreground" dateTime={review.created_at}>
                {formatDate(review.created_at)}
              </time>
            </div>
            <blockquote className="flex gap-2 text-sm text-foreground">
              <Quote aria-hidden className="mt-0.5 h-4 w-4 shrink-0 text-primary/60" />
              <p className="min-w-0 break-words">{review.comment}</p>
            </blockquote>
            <p className="text-sm">
              <span className="font-medium text-foreground">{review.reviewer_name}</span>
              {review.reviewer_role && <span className="text-muted-foreground"> · {review.reviewer_role}</span>}
            </p>
          </li>
        ))}
      </ul>

      {hiddenCount > 0 && (
        <Button
          aria-expanded={open}
          className="min-h-11 self-start"
          variant="ghost"
          onClick={() => void setOpen(open ? null : true)}
        >
          <ChevronDown
            aria-hidden
            className={cn("transition-transform duration-fast ease-smooth", open && "rotate-180")}
          />
          {open ? "Show fewer" : `Show ${hiddenCount} more review${hiddenCount === 1 ? "" : "s"}`}
        </Button>
      )}
    </section>
  );
}
