"use client";

import { useState } from "react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { AnswerForm } from "@/components/workspace/clarify/answer-form";
import { QuestionComposer } from "@/components/workspace/clarify/question-composer";
import { CommentsPanel } from "@/components/workspace/comments/comments-panel";
import { apiFetch } from "@/lib/client/api";
import type { WorkspaceComment } from "@/lib/workspace/phase3-server";
import type { Page, RequirementQuestion } from "@/lib/workspace/types";

interface QuestionThreadProps {
  workspaceId: string;
  initialPage: Page<RequirementQuestion>;
}

/** Owns the Q&A list's state so a freshly-asked question appears instantly
 * (composed here rather than router.refresh()-ing the whole page) and so
 * "Already asked — view thread" can scroll straight to it. */
export function QuestionThread({ workspaceId, initialPage }: QuestionThreadProps) {
  const [questions, setQuestions] = useState(initialPage.items);
  const [nextCursor, setNextCursor] = useState(initialPage.next_cursor);
  const [loadingMore, setLoadingMore] = useState(false);
  const [highlightId, setHighlightId] = useState<string | null>(null);
  const [openComments, setOpenComments] = useState<Record<string, Page<WorkspaceComment>>>({});

  function upsert(question: RequirementQuestion) {
    setQuestions((prev) => (prev.some((p) => p.id === question.id)
      ? prev.map((p) => (p.id === question.id ? question : p))
      : [question, ...prev]));
  }

  function viewThread(question: RequirementQuestion) {
    upsert(question);
    setHighlightId(question.id);
    document.getElementById(`question-${question.id}`)?.scrollIntoView({ behavior: "smooth", block: "center" });
  }

  async function loadMore() {
    if (!nextCursor) return;
    setLoadingMore(true);
    const page = await apiFetch<Page<RequirementQuestion>>(
      `/workspaces/${workspaceId}/questions?cursor=${encodeURIComponent(nextCursor)}&limit=20`,
    );
    setLoadingMore(false);
    if (!page) {
      toast.error("Could not load more questions.");
      return;
    }
    setQuestions((prev) => [...prev, ...page.items]);
    setNextCursor(page.next_cursor);
  }

  async function toggleComments(question: RequirementQuestion) {
    if (openComments[question.id]) {
      setOpenComments((prev) => {
        const { [question.id]: _closed, ...rest } = prev;
        return rest;
      });
      return;
    }
    const page = await apiFetch<Page<WorkspaceComment>>(`/workspaces/${workspaceId}/questions/${question.id}/comments?limit=20`);
    setOpenComments((prev) => ({ ...prev, [question.id]: page ?? { items: [] } }));
  }

  return (
    <div className="flex flex-col gap-4">
      <QuestionComposer workspaceId={workspaceId} onAsked={upsert} onViewThread={viewThread} />

      {questions.length === 0 ? (
        <p className="text-sm text-muted-foreground">No questions yet — be the first to ask.</p>
      ) : (
        <div className="flex flex-col gap-3">
          {questions.map((q) => {
            const opened = openComments[q.id];
            return (
              <div
                className={cn("card-base flex flex-col gap-2", q.id === highlightId && "ring-2 ring-primary")}
                id={`question-${q.id}`}
                key={q.id}
              >
                <div className="flex items-start justify-between gap-2">
                  <p className="min-w-0 flex-1 text-sm font-medium">{q.question}</p>
                  <span className="shrink-0 text-xs text-muted-foreground">
                    {q.asker_name} · {new Date(q.created_at).toLocaleDateString()}
                  </span>
                </div>

                {q.answer ? (
                  <div className="flex flex-col gap-1 rounded-md bg-muted p-2.5 text-sm">
                    <div className="flex items-center gap-2">
                      {q.is_assumption && <Badge variant="outline">Assumption</Badge>}
                      {q.answered_at && (
                        <span className="text-xs text-muted-foreground">Answered {new Date(q.answered_at).toLocaleDateString()}</span>
                      )}
                    </div>
                    <p className="whitespace-pre-wrap">{q.answer}</p>
                  </div>
                ) : q.is_assumption ? (
                  <Badge className="w-fit" variant="outline">Marked as assumption — no explicit answer</Badge>
                ) : (
                  <AnswerForm question={q} workspaceId={workspaceId} onAnswered={upsert} />
                )}

                <Button className="w-fit px-0" size="sm" variant="link" onClick={() => void toggleComments(q)}>
                  {opened ? "Hide comments" : `Comments (${q.comment_count})`}
                </Button>
                {opened && <CommentsPanel initialPage={opened} subjectId={q.id} subjectType="requirement_question" workspaceId={workspaceId} />}
              </div>
            );
          })}
        </div>
      )}

      {nextCursor && (
        <Button className="w-fit" disabled={loadingMore} variant="outline" onClick={() => void loadMore()}>
          {loadingMore ? "Loading…" : "Load more"}
        </Button>
      )}
    </div>
  );
}
