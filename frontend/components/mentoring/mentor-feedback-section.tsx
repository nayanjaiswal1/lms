"use client";

import { parseAsBoolean, useQueryState } from "nuqs";
import { MessageSquarePlus, Star } from "lucide-react";
import { Button } from "@/components/ui/button";
import { MentorRatingForm } from "@/components/mentoring/mentor-rating-form";

interface Props {
  mentorId: string;
  avgRating: number | null;
  ratingCount: number;
  canReview: boolean;
  initialRating: number | null;
  initialComment: string | null;
}

// "Mentee feedback" card — the rating summary is always visible (it's public
// aggregate data, same as the sidebar insights card), but the "leave a
// review" form only ever renders for a student with real mentorship history
// with this mentor. That's UX only: the server independently rejects a
// rating from anyone HasBeenMentoredBy doesn't cover (see feedback.Service.Submit),
// so hiding the button here is a courtesy, not the actual gate.
export function MentorFeedbackSection({
  mentorId,
  avgRating,
  ratingCount,
  canReview,
  initialRating,
  initialComment,
}: Props) {
  const [open, setOpen] = useQueryState("review-form", parseAsBoolean.withDefault(false));

  if (avgRating === null && !canReview) return null;

  return (
    <section className="rounded-xl border border-border bg-card p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h2 className="text-lg font-semibold">Mentee feedback</h2>
        {canReview && (
          <Button size="sm" variant="secondary" onClick={() => void setOpen(open ? null : true)}>
            <MessageSquarePlus aria-hidden className="h-4 w-4" />
            {open ? "Hide" : initialRating ? "Edit your review" : "Leave a review"}
          </Button>
        )}
      </div>

      {avgRating !== null && (
        <div className="mt-3 flex items-center gap-3">
          <span aria-hidden className="flex items-center gap-0.5 text-primary">
            {[1, 2, 3, 4, 5].map((n) => (
              <Star className="h-4 w-4" fill={n <= Math.round(avgRating) ? "currentColor" : "none"} key={n} />
            ))}
          </span>
          <span className="text-sm font-medium text-foreground">
            {avgRating.toFixed(1)} / 5.0 ({ratingCount} review{ratingCount === 1 ? "" : "s"})
          </span>
        </div>
      )}

      {canReview && open && (
        <div className="mt-4 border-t border-border pt-4">
          <MentorRatingForm initialComment={initialComment} initialRating={initialRating} mentorId={mentorId} />
        </div>
      )}
    </section>
  );
}
