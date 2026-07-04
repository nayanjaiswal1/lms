"use client";

import { useRef, useState, useTransition } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Textarea } from "@/components/ui/textarea";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { submitExperienceReportAction } from "@/lib/assessments/actions";
import type { ExperienceValue } from "@/lib/server/experience";

interface ExperienceReportPromptProps {
  attemptId: string;
  alreadyResponded: boolean;
  onDone: () => void;
}

const OPTIONS: { value: ExperienceValue; label: string }[] = [
  { value: "smooth", label: "Everything went smoothly" },
  { value: "issue", label: "I ran into a technical issue" },
  { value: "complaint", label: "I have feedback or a complaint" },
];

// Separate from the star-rating FeedbackPrompt (components/feedback) — this
// asks "did anything go wrong" right after the attempt, not "how would you
// rate this". subject_id is the attempt ID, not the assessment ID, so an
// issue is tied to the specific run the learner just finished.
export function ExperienceReportPrompt({ attemptId, alreadyResponded, onDone }: ExperienceReportPromptProps) {
  const [open, setOpen] = useState(!alreadyResponded);
  const [selected, setSelected] = useState<ExperienceValue | null>(null);
  const [isPending, startTransition] = useTransition();
  const descriptionRef = useRef<HTMLTextAreaElement>(null);

  if (alreadyResponded) return null;

  function close() {
    setOpen(false);
    onDone();
  }

  function handleSkip() {
    startTransition(async () => {
      const result = await submitExperienceReportAction({ subjectType: "assessment", subjectId: attemptId, skip: true });
      if (!result.ok) {
        toast.error(result.error ?? "Something went wrong. Please try again.");
        return;
      }
      close();
    });
  }

  function handleSubmit() {
    if (selected === null) return;
    startTransition(async () => {
      const description = descriptionRef.current?.value.trim() || undefined;
      const result = await submitExperienceReportAction({
        subjectType: "assessment",
        subjectId: attemptId,
        experience: selected,
        description,
      });
      if (!result.ok) {
        toast.error(result.error ?? "Something went wrong. Please try again.");
        return;
      }
      toast.success("Thanks for letting us know.");
      close();
    });
  }

  return (
    <Dialog open={open} onOpenChange={(next) => (next ? setOpen(true) : close())}>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>How did this assessment go?</DialogTitle>
          <DialogDescription>
            Let us know if you ran into any issues — this helps us fix problems quickly.
          </DialogDescription>
        </DialogHeader>

        <div className="flex flex-col gap-4">
          <RadioGroup
            aria-label="Assessment experience"
            disabled={isPending}
            value={selected ?? undefined}
            onValueChange={(value) => setSelected(value as ExperienceValue)}
          >
            {OPTIONS.map((option) => (
              <div className="flex items-center gap-3" key={option.value}>
                <RadioGroupItem id={`experience-${option.value}`} value={option.value} />
                <Label className="font-normal" htmlFor={`experience-${option.value}`}>
                  {option.label}
                </Label>
              </div>
            ))}
          </RadioGroup>

          {selected !== null && selected !== "smooth" && (
            <Textarea
              aria-label="Tell us what happened (optional)"
              disabled={isPending}
              placeholder="Tell us what happened (optional)"
              ref={descriptionRef}
            />
          )}
        </div>

        <DialogFooter>
          <Button disabled={isPending} type="button" variant="outline" onClick={handleSkip}>
            Skip
          </Button>
          <Button disabled={isPending || selected === null} type="button" onClick={handleSubmit}>
            {isPending ? "Submitting…" : "Submit"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
