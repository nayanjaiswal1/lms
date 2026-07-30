"use client";

import * as React from "react";
import { PanelRightClose, PanelRightOpen } from "lucide-react";

import { Button } from "@/components/ui/button";
import { CameraPip } from "@/components/assessments/camera-pip";
import { isAnswered, type AnswerValue } from "@/lib/assessments/use-answers";
import { cn } from "@/lib/utils";
import type { ProctoringConfig, StudentQuestion } from "@/lib/assessments/types";

interface QuestionPaletteProps {
  questions: StudentQuestion[];
  answers: Record<string, AnswerValue>;
  markedForReview: Record<string, boolean>;
  currentIndex: number;
  allowBacktrack: boolean;
  onJump: (index: number) => void;
  answeredCount: number;
  markedCount: number;
  progressPct: number;
  proctoring: ProctoringConfig;
  cameraStream: MediaStream | null;
  phoneConnected: boolean;
}

// Right-side question number grid (desktop only). Collapsible to a slim
// glimpse rail — with the new left section nav also taking width, both
// panels should be optional rather than always eating into the question
// column.
export function QuestionPalette({
  questions,
  answers,
  markedForReview,
  currentIndex,
  allowBacktrack,
  onJump,
  answeredCount,
  markedCount,
  progressPct,
  proctoring,
  cameraStream,
  phoneConnected,
}: QuestionPaletteProps) {
  const [collapsed, setCollapsed] = React.useState(false);

  if (collapsed) {
    return (
      <aside className="hidden lg:flex w-10 shrink-0 flex-col items-center border-l border-border bg-card/50 py-3">
        <Button
          variant="ghost"
          size="icon"
          aria-label="Show question palette"
          className="touch-target h-8 w-8"
          onClick={() => setCollapsed(false)}
        >
          <PanelRightOpen aria-hidden className="h-4 w-4" />
        </Button>
      </aside>
    );
  }

  return (
    <aside className="hidden lg:flex w-52 shrink-0 flex-col gap-4 overflow-y-auto border-l border-border bg-card/50 p-4">
      <div className="flex items-center justify-between">
        <span className="text-xs font-medium text-muted-foreground">Progress</span>
        <Button
          variant="ghost"
          size="icon"
          aria-label="Hide question palette"
          className="touch-target h-6 w-6"
          onClick={() => setCollapsed(true)}
        >
          <PanelRightClose aria-hidden className="h-3.5 w-3.5" />
        </Button>
      </div>

      {/* Progress summary */}
      <div className="flex flex-col gap-2">
        <div className="flex items-center justify-between">
          <span className="text-xs font-medium text-muted-foreground">Answered</span>
          <span className="text-xs font-semibold tabular-nums">
            {answeredCount}/{questions.length}
          </span>
        </div>
        <div className="progress-track">
          {/* eslint-disable-next-line no-restricted-syntax -- dynamic CSS variable for progress bar width */}
          <div className="progress-fill" style={{ "--progress": `${progressPct}%` } as React.CSSProperties} />
        </div>
        {markedCount > 0 && (
          <p className="text-xs text-muted-foreground">{markedCount} marked for review</p>
        )}
      </div>

      {/* Question number grid */}
      <div className="flex flex-col gap-2">
        <span className="text-xs font-medium text-muted-foreground">Questions</span>
        <div className="grid grid-cols-4 gap-1.5">
          {questions.map((q, i) => {
            const answered = isAnswered(answers[q.assessment_question_id]);
            const isCurrent = i === currentIndex;
            const isMarked = markedForReview[q.assessment_question_id] ?? false;
            return (
              <button
                key={q.assessment_question_id}
                onClick={() => (allowBacktrack ? onJump(i) : undefined)}
                disabled={!allowBacktrack && i !== currentIndex}
                aria-label={`Question ${i + 1}${answered ? ", answered" : ""}${isMarked ? ", marked for review" : ""}`}
                aria-current={isCurrent ? "step" : undefined}
                className={cn(
                  "flex h-9 w-full items-center justify-center rounded-md text-xs font-semibold tabular-nums transition-all duration-fast",
                  isCurrent
                    ? "bg-primary text-primary-foreground ring-2 ring-primary/30"
                    : isMarked && answered
                      ? "bg-ai text-ai-foreground ring-2 ring-primary"
                      : isMarked
                        ? "bg-primary/15 text-primary ring-2 ring-primary/60"
                        : answered
                          ? "bg-ai/15 text-ai"
                          : "bg-muted text-muted-foreground",
                  allowBacktrack && i !== currentIndex ? "cursor-pointer hover:opacity-75" : "cursor-default",
                )}
              >
                {i + 1}
              </button>
            );
          })}
        </div>
      </div>

      {/* Cameras — inline in the sidebar so it never overlaps the
          question content or the Next/Submit controls below */}
      {(proctoring.require_camera || proctoring.allow_secondary_camera) && (
        <div className="border-t border-border pt-3">
          <CameraPip stream={cameraStream} phoneConnected={phoneConnected} />
        </div>
      )}

      {/* Legend */}
      <div className="flex flex-col gap-1.5 border-t border-border pt-3">
        <div className="flex items-center gap-2">
          <span className="h-3 w-3 shrink-0 rounded-sm bg-primary" />
          <span className="text-xs text-muted-foreground">Current</span>
        </div>
        <div className="flex items-center gap-2">
          <span className="h-3 w-3 shrink-0 rounded-sm bg-ai/15" />
          <span className="text-xs text-muted-foreground">Answered</span>
        </div>
        <div className="flex items-center gap-2">
          <span className="h-3 w-3 shrink-0 rounded-sm bg-primary/15 ring-2 ring-primary/60" />
          <span className="text-xs text-muted-foreground">Marked for review</span>
        </div>
        <div className="flex items-center gap-2">
          <span className="h-3 w-3 shrink-0 rounded-sm bg-ai ring-2 ring-primary" />
          <span className="text-xs text-muted-foreground">Answered + marked</span>
        </div>
        <div className="flex items-center gap-2">
          <span className="h-3 w-3 shrink-0 rounded-sm bg-muted" />
          <span className="text-xs text-muted-foreground">Not answered</span>
        </div>
      </div>
    </aside>
  );
}
