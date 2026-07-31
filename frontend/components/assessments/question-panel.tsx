import { Bookmark, X } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { MCQQuestion } from "@/components/shared/mcq-question";
import { CodingQuestion } from "@/components/assessments/coding-question";
import { TranscriptInput } from "@/components/assessments/transcript-input";
import { SectionTabs } from "@/components/assessments/section-tabs";
import { saveAnswerAction } from "@/app/(app)/assessments/[id]/take/actions";
import { isMCQQuestion, isSubjectiveQuestion, SESSION_SUPERSEDED_MESSAGE } from "@/lib/assessments/types";
import type { useAnswers } from "@/lib/assessments/use-answers";
import type { AnswerValue, MCQAnswer, CodingAnswer, TranscriptAnswer } from "@/lib/assessments/use-answers";
import { cn } from "@/lib/utils";
import type { QuestionSection, StudentQuestion } from "@/lib/assessments/types";

interface QuestionPanelProps {
  current: StudentQuestion;
  currentAnswer: AnswerValue | undefined;
  isCurrentMarked: boolean;
  isCoding: boolean;
  currentIndex: number;
  totalQuestions: number;
  sections: QuestionSection[];
  attemptId: string;
  sessionToken: string;
  dispatch: ReturnType<typeof useAnswers>["dispatch"];
  onJump: (index: number) => void;
  onClearAnswer: () => void;
  markSupersededIfNeeded: (error: string | undefined) => boolean;
}

// Zone 2 center column: section tabs (mobile), the question meta header
// (index, badges, mark-for-review, clear-answer), and the question content
// itself (MCQ / subjective / coding), extracted verbatim out of TestRunner.
export function QuestionPanel({
  current,
  currentAnswer,
  isCurrentMarked,
  isCoding,
  currentIndex,
  totalQuestions,
  sections,
  attemptId,
  sessionToken,
  dispatch,
  onJump,
  onClearAnswer,
  markSupersededIfNeeded,
}: QuestionPanelProps) {
  return (
    <div className={cn("flex-1", isCoding ? "flex flex-col overflow-hidden" : "overflow-y-auto")}>
      <div
        className={
          isCoding
            ? "flex h-full flex-col px-3 pb-3 pt-4 sm:px-4 lg:px-6"
            : // This is the fixed full-screen exam takeover, not a page rendered
              // inside .app-shell/.app-content, so there is no ambient page padding
              // to double up on.
              // eslint-disable-next-line no-restricted-syntax -- see comment above
              "page-container py-6"
        }
      >
        {/* Section navigator — mobile/tablet horizontal tabs */}
        <SectionTabs currentType={current.type} sections={sections} onJump={onJump} />

        {/* Question meta — select-none prevents students from copy-pasting
            the question title and type labels out of the test. */}
        <div className={cn("flex select-none flex-col gap-2", isCoding ? "mb-3 shrink-0" : "mb-5")}>
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="flex items-baseline gap-1.5">
              <span className="text-2xl font-bold tabular-nums">
                Q{currentIndex + 1}
              </span>
              <span className="text-base text-muted-foreground">
                of {totalQuestions}
              </span>
            </div>
            <div className="flex flex-wrap items-center gap-3">
              <div className="flex flex-wrap items-center gap-1.5">
                <Badge className="capitalize" variant="secondary">
                  {current.type.replace("_", " ")}
                </Badge>
                <Badge className="capitalize" variant="secondary">
                  {current.difficulty}
                </Badge>
                <Badge className="tabular-nums" variant="outline">
                  {current.points} pt{current.points !== 1 ? "s" : ""}
                </Badge>
              </div>
              <div className="flex flex-wrap items-center gap-2">
                <Button
                  aria-label={isCurrentMarked ? "Remove review mark" : "Mark this question for review"}
                  className={cn(
                    "gap-2",
                    isCurrentMarked ? "border-primary text-primary" : "text-muted-foreground",
                  )}
                  size="sm"
                  variant="outline"
                  onClick={() =>
                    dispatch({ kind: "toggleMark", qid: current.assessment_question_id })
                  }
                >
                  <Bookmark
                    aria-hidden
                    className={cn("h-3.5 w-3.5", isCurrentMarked && "fill-primary")}
                  />
                  {isCurrentMarked ? "Marked for review" : "Mark for review"}
                </Button>
                <Button
                  aria-label="Clear current answer"
                  className="gap-2 text-muted-foreground"
                  disabled={!currentAnswer}
                  size="sm"
                  variant="outline"
                  onClick={onClearAnswer}
                >
                  <X aria-hidden className="h-3.5 w-3.5" />
                  Clear answer
                </Button>
              </div>
            </div>
          </div>
          <p className="text-sm font-medium text-muted-foreground">{current.title}</p>
        </div>

        {/* Question content */}
        {isMCQQuestion(current) || isSubjectiveQuestion(current) ? (
          <div className="card-base select-none p-6">
            {isMCQQuestion(current) ? (
              <MCQQuestion
                content={current.content}
                selected={(currentAnswer as MCQAnswer | undefined)?.selected ?? []}
                onToggle={(optionId, multiple) =>
                  dispatch({
                    kind: "toggleOption",
                    qid: current.assessment_question_id,
                    optionId,
                    multiple,
                  })
                }
              />
            ) : (
              <TranscriptInput
                prompt={current.content.prompt}
                value={(currentAnswer as TranscriptAnswer | undefined)?.transcript ?? ""}
                onChange={(text) =>
                  dispatch({
                    kind: "setTranscript",
                    qid: current.assessment_question_id,
                    transcript: text,
                  })
                }
                onSave={(text) =>
                  void saveAnswerAction(
                    attemptId,
                    sessionToken,
                    current.assessment_question_id,
                    null,
                    0,
                    text,
                  ).then((res) => markSupersededIfNeeded(res.error))
                }
              />
            )}
          </div>
        ) : (
          <div className="min-h-0 flex-1">
            <CodingQuestion
              assessmentQuestionId={current.assessment_question_id}
              attemptId={attemptId}
              content={current.content}
              sessionToken={sessionToken}
              value={currentAnswer as CodingAnswer | undefined}
              onCode={(code, language) =>
                dispatch({
                  kind: "setCode",
                  qid: current.assessment_question_id,
                  code,
                  language,
                })
              }
              onLanguage={(language, starter) =>
                dispatch({
                  kind: "setLanguage",
                  qid: current.assessment_question_id,
                  language,
                  starter,
                })
              }
              onSuperseded={() => markSupersededIfNeeded("Your session moved to another device or tab. This window is no longer active.")}
            />
          </div>
        )}
      </div>
    </div>
  );
}
