"use client";

import { useRef, useState, useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { askQuestionAction, similarQuestionsAction } from "@/lib/workspace/phase3-actions";
import type { RequirementQuestion } from "@/lib/workspace/types";

const DEBOUNCE_MS = 400;
const MIN_LENGTH = 8;

interface QuestionComposerProps {
  workspaceId: string;
  onAsked: (question: RequirementQuestion) => void;
  onViewThread: (question: RequirementQuestion) => void;
}

/** Member+ compose box for the requirement Q&A. Debounced similarity check
 * runs on every keystroke (04-frontend.md §7 "Already asked — view thread")
 * — wired into the textarea's onChange, not a useEffect watcher. */
export function QuestionComposer({ workspaceId, onAsked, onViewThread }: QuestionComposerProps) {
  const [text, setText] = useState("");
  const [similar, setSimilar] = useState<RequirementQuestion[]>([]);
  const [checking, startCheck] = useTransition();
  const [submitting, setSubmitting] = useState(false);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  function handleChange(next: string) {
    setText(next);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (next.trim().length < MIN_LENGTH) {
      setSimilar([]);
      return;
    }
    debounceRef.current = setTimeout(() => {
      startCheck(async () => {
        const result = await similarQuestionsAction(workspaceId, next.trim());
        setSimilar(result.ok ? (result.data ?? []) : []);
      });
    }, DEBOUNCE_MS);
  }

  async function submit() {
    if (text.trim().length < MIN_LENGTH) {
      toast.error("Ask a more specific question.");
      return;
    }
    setSubmitting(true);
    const result = await askQuestionAction(workspaceId, text.trim());
    setSubmitting(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    if (result.data) {
      onAsked(result.data.question);
      if (result.data.duplicate) toast.info("That looks like an existing question — linked to the thread.");
      else toast.success("Question posted.");
    }
    setText("");
    setSimilar([]);
  }

  return (
    <div className="flex flex-col gap-2">
      <Textarea
        placeholder="Ask the project owner something about the requirement…"
        rows={3}
        value={text}
        onChange={(e) => handleChange(e.target.value)}
      />

      {checking && <p className="text-xs text-muted-foreground">Checking for similar questions…</p>}

      {!checking && similar.length > 0 && (
        <div className="ai-surface flex flex-col gap-1.5 rounded-md p-3">
          <span className="ai-badge w-fit">Similar</span>
          <ul className="flex flex-col gap-1">
            {similar.map((q) => (
              <li className="flex items-center justify-between gap-2 text-sm" key={q.id}>
                <span className="min-w-0 truncate">{q.question}</span>
                <button className="shrink-0 text-xs text-primary hover:underline" type="button" onClick={() => onViewThread(q)}>
                  Already asked — view thread
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}

      <Button className="w-fit" disabled={submitting} onClick={() => void submit()}>
        {submitting ? "Posting…" : "Ask"}
      </Button>
    </div>
  );
}
