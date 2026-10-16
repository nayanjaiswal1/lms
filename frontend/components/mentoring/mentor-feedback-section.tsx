"use client";

import { parseAsBoolean, useQueryState } from "nuqs";
import { MessageSquarePlus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { MentorRatingForm } from "@/components/mentoring/mentor-rating-form";
import { StarRating } from "@/components/mentoring/star-rating";

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
    <section aria-labelledby="mentor-feedback-title" className="card-raised">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex flex-col gap-2">
          <h2 className="subsection-title" id="mentor-feedback-title">
            Mentee feedback
          </h2>
          {avgRating !== null ? (
            <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
              <span className="text-4xl font-bold tabular-nums text-foreground">{avgRating.toFixed(1)}</span>
              <div className="flex flex-col gap-1">
                <StarRating value={avgRating} />
                <span className="text-sm text-muted-foreground">
                  out of 5 · {ratingCount} review{ratingCount === 1 ? "" : "s"}
                </span>
              </div>
            </div>
          ) : (
            <p className="text-sm text-muted-foreground">No ratings yet — yours would be the first.</p>
          )}
        </div>
        {canReview && (
          <Button
            aria-expanded={open}
            className="min-h-11"
            variant={open ? "outline" : "secondary"}
            onClick={() => void setOpen(open ? null : true)}
          >
            <MessageSquarePlus aria-hidden />
            {open ? "Hide" : initialRating ? "Edit your review" : "Leave a review"}
          </Button>
        )}
      </div>

      {canReview && open && (
        <div className="mt-6 border-t border-border pt-6">
          <MentorRatingForm initialComment={initialComment} initialRating={initialRating} mentorId={mentorId} />
        </div>
      )}
    </section>
  );
}
