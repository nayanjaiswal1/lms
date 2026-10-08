"use client";

import { useState } from "react";

import { Button } from "@/components/ui/button";
import { DEMO_QUIZ } from "@/app/demo/tour/mock-data";
import { cn } from "@/lib/utils";

interface QuizState {
  index: number;
  picked: number | null;
  score: number;
}

const INITIAL: QuizState = { index: 0, picked: null, score: 0 };

export function QuizDemo() {
  const [state, setState] = useState<QuizState>(INITIAL);
  const total = DEMO_QUIZ.questions.length;
  const question = DEMO_QUIZ.questions[state.index];

  if (!question) {
    return (
      <div className="mx-auto flex max-w-xl flex-col gap-4">
        <h1>{DEMO_QUIZ.title}</h1>
        <section className="card-base flex flex-col items-center gap-3 p-6 text-center">
          <p className="text-3xl font-bold tabular-nums">{state.score} / {total}</p>
          <p className="text-muted-foreground">{state.score === total ? "Perfect score." : "Retake to improve your score."}</p>
          <Button variant="outline" onClick={() => setState(INITIAL)}>Retake</Button>
        </section>
      </div>
    );
  }

  const answered = state.picked !== null;

  return (
    <div className="mx-auto flex max-w-xl flex-col gap-4">
      <h1>{DEMO_QUIZ.title}</h1>
      <section className="card-base flex flex-col gap-4 p-6">
        <p className="text-xs tabular-nums text-muted-foreground">Question {state.index + 1} of {total}</p>
        <p className="font-medium">{question.prompt}</p>
        <div className="flex flex-col gap-2">
          {question.options.map((option, i) => (
            <Button
              className={cn(
                "flex h-auto w-full items-center justify-start rounded-lg border border-border px-4 py-2.5 text-left font-mono text-sm",
                answered && i === question.answer && "border-success bg-success/10",
                answered && i === state.picked && i !== question.answer && "border-destructive bg-destructive/10",
              )}
              disabled={answered}
              key={option}
              type="button"
              variant="unstyled"
              onClick={() => setState((s) => ({ ...s, picked: i, score: s.score + (i === question.answer ? 1 : 0) }))}
            >
              {option}
            </Button>
          ))}
        </div>
        {answered && (
          <Button className="self-end" size="sm" onClick={() => setState((s) => ({ ...s, index: s.index + 1, picked: null }))}>
            {state.index + 1 === total ? "See result" : "Next"}
          </Button>
        )}
      </section>
    </div>
  );
}
