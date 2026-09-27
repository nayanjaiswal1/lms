"use client";

import { useState } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { useProjectRole } from "@/components/workspace/project-role-provider";
import { answerQuestionAction } from "@/lib/workspace/phase3-actions";
import type { RequirementQuestion } from "@/lib/workspace/types";

const ASSUMPTION_WAIT_DAYS = 5;
const ASSUMPTION_WAIT_MS = ASSUMPTION_WAIT_DAYS * 24 * 60 * 60 * 1000;

interface AnswerFormProps {
  workspaceId: string;
  question: RequirementQuestion;
  onAnswered: (question: RequirementQuestion) => void;
}

/** Owner answers any time, or can defer straight to "you decide" (an
 * assumption, no answer text needed). A non-owner manager can only mark a
 * question as an assumption, and only once it's sat unanswered ≥5 days
 * (contract-phase3.md AnswerQuestion — ErrTooEarly otherwise). */
export function AnswerForm({ workspaceId, question, onAnswered }: AnswerFormProps) {
  const { isOwner, atLeast } = useProjectRole();
  const [answer, setAnswer] = useState("");
  const [pending, setPending] = useState(false);

  const askedAt = new Date(question.created_at).getTime();
  const oldEnough = Date.now() - askedAt >= ASSUMPTION_WAIT_MS;
  const canManagerAssume = !isOwner && atLeast("manager");

  if (!isOwner && !canManagerAssume) return null;

  async function submit(payload: { answer?: string; is_assumption?: boolean }) {
    setPending(true);
    const result = await answerQuestionAction(workspaceId, question.id, payload);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    if (result.data) onAnswered(result.data);
    setAnswer("");
  }

  if (isOwner) {
    return (
      <div className="flex flex-col gap-2">
        <Textarea
          disabled={pending}
          placeholder="Write an answer…"
          rows={2}
          value={answer}
          onChange={(e) => setAnswer(e.target.value)}
        />
        <div className="flex flex-wrap gap-2">
          <Button
            disabled={pending || answer.trim().length === 0}
            size="sm"
            onClick={() => void submit({ answer: answer.trim() })}
          >
            {pending ? "Saving…" : "Answer"}
          </Button>
          <Button disabled={pending} size="sm" variant="outline" onClick={() => void submit({ is_assumption: true })}>
            You decide → mark as assumption
          </Button>
        </div>
      </div>
    );
  }

  const assumeButton = (
    <Button disabled={pending || !oldEnough} size="sm" variant="outline" onClick={() => void submit({ is_assumption: true })}>
      {pending ? "Marking…" : "Mark as assumption"}
    </Button>
  );

  if (oldEnough) return assumeButton;

  return (
    <Tooltip>
      <TooltipTrigger asChild><span>{assumeButton}</span></TooltipTrigger>
      <TooltipContent>Available {ASSUMPTION_WAIT_DAYS} days after the question was asked.</TooltipContent>
    </Tooltip>
  );
}
