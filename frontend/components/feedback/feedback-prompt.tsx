"use client";

import { useRef, useState, useTransition } from "react";
import { Star } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { submitFeedbackAction } from "@/lib/feedback/actions";
import type { FeedbackSubjectType } from "@/lib/server/feedback";

interface FeedbackPromptProps {
  subjectType: FeedbackSubjectType;
  subjectId: string;
  alreadyResponded: boolean;
  title?: string;
}

const SUBJECT_LABEL: Record<FeedbackSubjectType, string> = {
  course: "course",
  assessment: "assessment",
  lab: "lab",
  mentor: "mentor",
};

export function FeedbackPrompt({ subjectType, subjectId, alreadyResponded, title }: FeedbackPromptProps) {
  const [open, setOpen] = useState(!alreadyResponded);
  const [rating, setRating] = useState(0);
  const [isPending, startTransition] = useTransition();
  const commentRef = useRef<HTMLTextAreaElement>(null);

  if (alreadyResponded) return null;

  function handleSkip() {
    startTransition(async () => {
      const result = await submitFeedbackAction({ subjectType, subjectId, skip: true });
      if (result.ok) {
        toast.success("Thanks — we won't ask again.");
        setOpen(false);
      } else {
        toast.error(result.error ?? "Something went wrong. Please try again.");
      }
    });
  }

  function handleSubmit() {
    if (rating === 0) return;
    startTransition(async () => {
      const comment = commentRef.current?.value.trim() || undefined;
      const result = await submitFeedbackAction({ subjectType, subjectId, rating, comment });
      if (result.ok) {
        toast.success("Thanks for your feedback!");
        setOpen(false);
      } else {
        toast.error(result.error ?? "Something went wrong. Please try again.");
      }
    });
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>{title ?? `Rate this ${SUBJECT_LABEL[subjectType]}`}</DialogTitle>
          <DialogDescription>
            Your feedback helps us improve. This only takes a moment.
          </DialogDescription>
        </DialogHeader>

        <div className="flex flex-col gap-4">
          <div aria-label="Star rating" className="flex items-center gap-1" role="radiogroup">
            {[1, 2, 3, 4, 5].map((n) => (
              <button
                aria-label={`${n} star${n === 1 ? "" : "s"}`}
                aria-pressed={rating >= n}
                className="touch-target text-primary"
                disabled={isPending}
                key={n}
                type="button"
                onClick={() => setRating(n)}
              >
                <Star aria-hidden className="h-6 w-6" fill={rating >= n ? "currentColor" : "none"} />
              </button>
            ))}
          </div>

          <Textarea
            aria-label="Additional comments (optional)"
            disabled={isPending}
            placeholder="Anything you'd like to add? (optional)"
            ref={commentRef}
          />
        </div>

        <DialogFooter>
          <Button disabled={isPending} type="button" variant="outline" onClick={handleSkip}>
            Skip
          </Button>
          <Button disabled={isPending || rating === 0} type="button" onClick={handleSubmit}>
            {isPending ? "Submitting…" : "Submit"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
