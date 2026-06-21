"use client";

import { useState, useActionState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { AIFeedbackCard } from "@/components/practice/ai-feedback-card";
import { submitAnswerAction } from "@/lib/practice/actions";
import type { PracticeItem } from "@/lib/server/practice";
import ROUTES from "@/lib/routes";

interface PracticeQuestionProps {
  sessionId: string;
  item: PracticeItem;
  isLast: boolean;
}

export function PracticeQuestion({ sessionId, item, isLast }: PracticeQuestionProps) {
  const router = useRouter();
  const [answer, setAnswer] = useState(item.user_answer ?? "");

  const [state, formAction, pending] = useActionState(
    async (_prev: { error?: string } | null) => {
      if (!answer.trim()) return { error: "Please enter an answer before submitting." };
      const result = await submitAnswerAction(sessionId, item.position, answer.trim());
      if (!result.ok) return { error: result.error };
      if (isLast) {
        router.push(ROUTES.practiceSession(sessionId));
      } else {
        router.push(`${ROUTES.practiceSession(sessionId)}?q=${item.position + 1}`);
      }
      return null;
    },
    null,
  );

  const isAnswered = item.answered_at !== null;

  return (
    <div className="flex flex-col gap-6">
      <div className="card-base p-6">
        <p className="text-sm text-muted-foreground">Question {item.position + 1}</p>
        <p className="mt-2 text-base font-medium leading-relaxed">{item.question_text}</p>
      </div>

      {isAnswered ? (
        <div className="flex flex-col gap-3">
          <h3 className="text-sm font-medium text-muted-foreground">Your answer</h3>
          <div className="card-base p-4">
            <p className="whitespace-pre-wrap text-sm">{item.user_answer}</p>
          </div>
          {item.ai_feedback && <AIFeedbackCard feedback={item.ai_feedback} />}
          {!item.ai_feedback && item.answered_at && (
            <p className="text-sm text-muted-foreground">AI feedback is being generated…</p>
          )}
        </div>
      ) : (
        <form action={formAction} className="flex flex-col gap-3">
          <Textarea
            value={answer}
            onChange={(e) => setAnswer(e.target.value)}
            placeholder="Type your answer here…"
            rows={8}
            aria-label="Your answer"
            disabled={pending}
            className="resize-none font-mono text-sm"
          />
          {state?.error && <p className="text-sm text-destructive">{state.error}</p>}
          <div className="flex justify-end gap-3">
            <Button type="submit" disabled={pending || !answer.trim()}>
              {pending ? "Submitting…" : isLast ? "Submit & finish" : "Submit & next"}
            </Button>
          </div>
        </form>
      )}
    </div>
  );
}
