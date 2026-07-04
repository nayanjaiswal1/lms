"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { ReviewForm } from "@/components/courses/review-form";
import { submitFeedbackAction } from "@/lib/feedback/actions";

interface CourseCompletionPromptProps {
  courseId: string;
}

// Course completion reuses the existing ReviewForm (writes course_reviews,
// which already feeds the catalog/detail rating aggregate) rather than the
// generic FeedbackPrompt star widget. This wrapper adds the one-time Skip
// affordance and mirrors the chosen rating into the feedback table so
// getMyFeedback('course', courseId) stops returning null after either path.
export function CourseCompletionPrompt({ courseId }: CourseCompletionPromptProps) {
  const [open, setOpen] = useState(true);
  const [isSkipping, startSkipTransition] = useTransition();

  async function handleReviewed(rating: number) {
    const result = await submitFeedbackAction({ subjectType: "course", subjectId: courseId, rating });
    if (result.ok) {
      toast.success("Thanks for your feedback!");
    } else {
      toast.error(result.error ?? "Your rating was saved, but we couldn't record it as feedback.");
    }
    setOpen(false);
  }

  function handleSkip() {
    startSkipTransition(async () => {
      const result = await submitFeedbackAction({ subjectType: "course", subjectId: courseId, skip: true });
      if (result.ok) {
        toast.success("Thanks — we won't ask again.");
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
          <DialogTitle>You completed this course</DialogTitle>
          <DialogDescription>
            How was it? Your rating helps other learners decide.
          </DialogDescription>
        </DialogHeader>

        <ReviewForm courseId={courseId} initialRating={null} onSubmitted={handleReviewed} />

        <DialogFooter>
          <Button disabled={isSkipping} type="button" variant="outline" onClick={handleSkip}>
            Skip
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
