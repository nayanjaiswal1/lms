"use client";

import { useEffect, useState, useTransition } from "react";
import { toast } from "sonner";

import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { apiFetch } from "@/lib/client/api";
import { promoteCaptureAction } from "@/app/(app)/captures/actions";
import type { Capture, CaptureDetail } from "@/lib/server/captures";

interface CapturePromoteDialogProps {
  capture: Capture;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

interface FormState {
  title: string;
  content: string;
  category: string;
  subcategory: string;
  mergeIntoId: string;
}

function toFormState(capture: Capture): FormState {
  return {
    title: capture.title ?? "",
    content: capture.content ?? "",
    category: capture.category ?? "",
    subcategory: capture.subcategory ?? "",
    mergeIntoId: "",
  };
}

// Fetches the capture's live similar_entries on open (client-only interaction,
// no Server Component equivalent for "refetch when this dialog opens") and
// lets the reviewer edit the AI's suggestion before promoting it into the
// journal (kind=note) or an SRS flashcard (kind=question).
export function CapturePromoteDialog({ capture, open, onOpenChange }: CapturePromoteDialogProps) {
  const [detail, setDetail] = useState<CaptureDetail | null>(null);
  const [form, setForm] = useState<FormState>(() => toFormState(capture));
  const [isPending, startTransition] = useTransition();
  const isQuestion = capture.kind === "question";

  useEffect(() => {
    if (!open) return;
    setForm(toFormState(capture));
    setDetail(null);
    apiFetch<CaptureDetail>(`/captures/${capture.id}`).then(setDetail);
  }, [open, capture]);

  function submit() {
    startTransition(async () => {
      const result = await promoteCaptureAction(capture.id, {
        title: form.title,
        content: form.content,
        category: form.category || undefined,
        subcategory: form.subcategory || undefined,
        merge_into_id: form.mergeIntoId || undefined,
      });
      if (!result.ok) {
        toast.error(result.error ?? "Couldn't save this capture.");
        return;
      }
      toast.success(isQuestion ? "Flashcard saved." : "Journal entry saved.");
      onOpenChange(false);
    });
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="modal-responsive max-w-lg">
        <DialogHeader>
          <DialogTitle>{isQuestion ? "Review flashcard" : "Review journal entry"}</DialogTitle>
          <DialogDescription>
            {isQuestion
              ? "Edit the question/answer before saving it as a spaced-repetition card."
              : "Edit the title, category, and content before saving it to your journal."}
          </DialogDescription>
        </DialogHeader>

        <div className="form-stack">
          {!isQuestion && (
            <div className="grid grid-cols-1 gap-2 md:grid-cols-2">
              <Input
                placeholder="Category"
                value={form.category}
                onChange={(e) => setForm({ ...form, category: e.target.value })}
              />
              <Input
                placeholder="Subcategory"
                value={form.subcategory}
                onChange={(e) => setForm({ ...form, subcategory: e.target.value })}
              />
            </div>
          )}
          <Input
            placeholder={isQuestion ? "Question" : "Title"}
            value={form.title}
            onChange={(e) => setForm({ ...form, title: e.target.value })}
          />
          <Textarea
            className="min-h-32"
            placeholder={isQuestion ? "Answer" : "Content"}
            value={form.content}
            onChange={(e) => setForm({ ...form, content: e.target.value })}
          />

          {detail && detail.similar_entries.length > 0 && (
            <div className="ai-surface flex flex-col gap-1.5 p-3 text-sm">
              <p className="ai-badge w-fit">AI</p>
              <p className="text-muted-foreground">
                {isQuestion ? "You may already have a card for this:" : "You may already have a note on this:"}
              </p>
              <div className="flex flex-col gap-1">
                {detail.similar_entries.map((m) => (
                  <label className="flex items-center gap-2 text-foreground" key={m.id}>
                    <input
                      checked={form.mergeIntoId === m.id}
                      name="merge-into"
                      type="radio"
                      value={m.id}
                      onChange={() => setForm({ ...form, mergeIntoId: m.id })}
                    />
                    {m.title}
                  </label>
                ))}
                <label className="flex items-center gap-2 text-foreground">
                  <input
                    checked={form.mergeIntoId === ""}
                    name="merge-into"
                    type="radio"
                    value=""
                    onChange={() => setForm({ ...form, mergeIntoId: "" })}
                  />
                  Save as new
                </label>
              </div>
            </div>
          )}
        </div>

        <DialogFooter>
          <Button disabled={isPending} variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button disabled={isPending || !form.title.trim() || !form.content.trim()} onClick={submit}>
            {form.mergeIntoId ? "Merge" : "Save"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
