"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { ChevronLeft, ChevronRight, Send, TriangleAlert, X } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { ProctorBanner } from "@/components/assessments/proctor-banner";
import { ProctorPreflight } from "@/components/assessments/proctor-preflight";
import { CameraPip } from "@/components/assessments/camera-pip";
import { MCQQuestion } from "@/components/assessments/mcq-question";
import { CodingQuestion } from "@/components/assessments/coding-question";
import { TranscriptInput } from "@/components/assessments/transcript-input";
import { useProctor } from "@/lib/assessments/use-proctor";
import { useCameraSetup } from "@/lib/assessments/use-camera-setup";
import {
  useAnswers,
  type AnswerValue,
  type MCQAnswer,
  type CodingAnswer,
  type TranscriptAnswer,
} from "@/lib/assessments/use-answers";
import {
  saveAnswerAction,
  submitAttemptAction,
  recordEventAction,
} from "@/app/(app)/assessments/[id]/take/actions";
import ROUTES from "@/lib/routes";
import { isMCQQuestion, isSubjectiveQuestion } from "@/lib/assessments/types";
import { cn } from "@/lib/utils";
import type { AttemptPayload } from "@/lib/assessments/types";

interface TestRunnerProps {
  payload: AttemptPayload;
}

type Stage = "camera" | "active";
type Confirming = "none" | "submit" | "exit";

// All UI state lives in two useState calls; answer/nav/timing state in hooks.
export function TestRunner({ payload }: TestRunnerProps) {
  const { attempt, questions, proctoring, meta } = payload;
  const router = useRouter();
  const { state, dispatch, answeredCount } = useAnswers(questions);
  const cameraSetup = useCameraSetup(proctoring.require_camera);

  const [stage, setStage] = React.useState<Stage>("camera");
  const [confirming, setConfirming] = React.useState<Confirming>("none");

  const resultHref = ROUTES.assessmentResult(attempt.id);
  const submittedRef = React.useRef(false);
  const { stopStream } = cameraSetup;

  const finishTo = React.useCallback(
    (message: string) => {
      toast(message);
      router.push(resultHref);
    },
    [router, resultHref],
  );

  const submit = React.useCallback(
    async (reason: string) => {
      if (submittedRef.current) return;
      submittedRef.current = true;
      dispatch({ kind: "submitting", value: true });
      const res = await submitAttemptAction(attempt.id);
      if (!res.ok) {
        submittedRef.current = false;
        dispatch({ kind: "submitting", value: false });
        toast.error(res.error ?? "Could not submit.");
        return;
      }
      stopStream();
      if (document.fullscreenElement) void document.exitFullscreen().catch(() => undefined);
      finishTo(reason);
    },
    [attempt.id, dispatch, finishTo, stopStream],
  );

  const proctor = useProctor({
    config: proctoring,
    enabled: stage === "active",
    durationSeconds: Math.max(
      1,
      attempt.expires_at
        ? Math.floor((new Date(attempt.expires_at).getTime() - Date.now()) / 1000)
        : meta.duration_minutes * 60,
    ),
    onEvent: async (event) => {
      const res = await recordEventAction(
        attempt.id,
        event.type,
        event.severity,
        event.metadata,
      );
      if (res.autoSubmitted)
        void submit("Your test was submitted automatically due to a policy violation.");
    },
    onTimeUp: () => void submit("Time is up — your test was submitted."),
  });

  const flush = React.useCallback(
    (qid: string, value: AnswerValue | undefined) => {
      if (!value) return;
      if ("transcript" in value) {
        void saveAnswerAction(attempt.id, qid, null, 0, value.transcript);
      } else {
        void saveAnswerAction(attempt.id, qid, value, 0);
      }
    },
    [attempt.id],
  );

  const current = questions[state.index];
  const currentAnswer = current ? state.answers[current.assessment_question_id] : undefined;

  const clearCurrentAnswer = React.useCallback(() => {
    if (!current) return;
    const qid = current.assessment_question_id;
    dispatch({ kind: "clearAnswer", qid });
    if (isMCQQuestion(current)) {
      void saveAnswerAction(attempt.id, qid, { selected: [] }, 0);
    } else if (isSubjectiveQuestion(current)) {
      void saveAnswerAction(attempt.id, qid, null, 0, "");
    }
  }, [attempt.id, current, dispatch]);

  const goto = (index: number) => {
    if (current)
      flush(current.assessment_question_id, state.answers[current.assessment_question_id]);
    dispatch({ kind: "goto", index });
  };

  if (!current) {
    return (
      <div className="fixed inset-0 z-modal flex items-center justify-center bg-background">
        <p className="text-muted-foreground">This assessment has no questions.</p>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 z-modal bg-background">

      {/* ── Camera pre-flight stage ──────────────────────────────────────── */}
      {stage === "camera" && (
        <div className="h-full overflow-y-auto">
          <ProctorPreflight
            meta={meta}
            proctoring={proctoring}
            setup={cameraSetup}
            onBegin={() => {
              if (proctoring.require_fullscreen) proctor.requestFullscreen();
              setStage("active");
            }}
          />
        </div>
      )}

      {/* ── Active test stage — three-zone layout ────────────────────────── */}
      {stage === "active" && (
        <div className="flex h-full flex-col">

          {/* Zone 1: ProctorBanner — shrink-0 at top */}
          <ProctorBanner
            answered={answeredCount}
            secondsLeft={proctor.secondsLeft}
            total={questions.length}
            violations={proctor.violations}
            onExit={() => setConfirming("exit")}
          />

          {/* Zone 2: Scrollable question content */}
          <div className="relative flex-1 overflow-y-auto">

            {/* Exit confirmation overlay */}
            {confirming === "exit" && (
              <div className="absolute inset-0 z-overlay flex items-center justify-center bg-background/80 p-4 backdrop-blur-sm">
                <div className="w-full max-w-sm rounded-2xl border border-border bg-card p-6 shadow-raised">
                  <div className="mb-4 flex flex-col items-center gap-3 text-center">
                    <span className="flex h-12 w-12 items-center justify-center rounded-full bg-destructive/10">
                      <TriangleAlert aria-hidden className="h-6 w-6 text-destructive" />
                    </span>
                    <div>
                      <h2 className="text-lg font-semibold">Exit test?</h2>
                      <p className="mt-1 text-sm text-muted-foreground">
                        Your answers are saved. The attempt stays open — check if retakes are
                        available to resume.
                      </p>
                    </div>
                  </div>
                  <div className="flex gap-3">
                    <Button
                      variant="outline"
                      onClick={() => setConfirming("none")}
                      className="flex-1"
                    >
                      Stay in test
                    </Button>
                    <Button
                      variant="destructive"
                      className="flex-1"
                      onClick={() => {
                        stopStream();
                        if (document.fullscreenElement)
                          void document.exitFullscreen().catch(() => undefined);
                        router.push(ROUTES.ASSESSMENTS);
                      }}
                    >
                      Exit
                    </Button>
                  </div>
                </div>
              </div>
            )}

            {/* Submit confirmation overlay */}
            {confirming === "submit" && (
              <div className="absolute inset-0 z-overlay flex items-center justify-center bg-background/80 p-4 backdrop-blur-sm">
                <div className="w-full max-w-sm rounded-2xl border border-border bg-card p-6 shadow-raised">
                  <div className="mb-4 flex flex-col items-center gap-3 text-center">
                    <span className="flex h-12 w-12 items-center justify-center rounded-full bg-primary/10">
                      <Send aria-hidden className="h-6 w-6 text-primary" />
                    </span>
                    <div>
                      <h2 className="text-lg font-semibold">Submit test?</h2>
                      <p className="mt-1 text-sm text-muted-foreground">
                        {answeredCount} of {questions.length} answered.{" "}
                        {answeredCount < questions.length &&
                          `${questions.length - answeredCount} question${
                            questions.length - answeredCount !== 1 ? "s" : ""
                          } will be left blank.`}
                      </p>
                    </div>
                  </div>
                  <div className="flex gap-3">
                    <Button
                      variant="outline"
                      disabled={state.submitting}
                      onClick={() => setConfirming("none")}
                      className="flex-1"
                    >
                      Keep reviewing
                    </Button>
                    <Button
                      disabled={state.submitting || proctor.secondsLeft === 0}
                      onClick={() => void submit("Test submitted. Good job!")}
                      className="flex-1"
                    >
                      {state.submitting ? (
                        "Submitting…"
                      ) : (
                        <>
                          <Send aria-hidden /> Submit
                        </>
                      )}
                    </Button>
                  </div>
                </div>
              </div>
            )}

            <div className="page-container py-6">
              {/* Question meta */}
              <div className="mb-5 flex flex-col gap-2">
                <div className="flex items-center justify-between gap-3">
                  <div className="flex items-baseline gap-1.5">
                    <span className="text-2xl font-bold tabular-nums">
                      Q{state.index + 1}
                    </span>
                    <span className="text-base text-muted-foreground">
                      of {questions.length}
                    </span>
                  </div>
                  <div className="flex items-center gap-1.5">
                    <Badge variant="secondary" className="capitalize">
                      {current.type.replace("_", " ")}
                    </Badge>
                    <Badge variant="secondary" className="capitalize">
                      {current.difficulty}
                    </Badge>
                    <Badge variant="outline" className="tabular-nums">
                      {current.points} pt{current.points !== 1 ? "s" : ""}
                    </Badge>
                  </div>
                </div>
                <p className="text-sm font-medium text-muted-foreground">{current.title}</p>
              </div>

              {/* Question content */}
              {isMCQQuestion(current) || isSubjectiveQuestion(current) ? (
                <div className="card-base p-6">
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
                          attempt.id,
                          current.assessment_question_id,
                          null,
                          0,
                          text,
                        )
                      }
                    />
                  )}
                </div>
              ) : (
                <CodingQuestion
                  content={current.content}
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
                />
              )}
            </div>
          </div>

          {/* Zone 3: Bottom navigation bar — shrink-0 at bottom */}
          <div className="shrink-0 border-t border-border bg-background/95 px-4 py-3 backdrop-blur-sm sm:px-6">
            <div className="flex items-center gap-3">
              {/* Previous */}
              <Button
                variant="outline"
                size="sm"
                disabled={state.index === 0 || !meta.allow_backtrack}
                onClick={() => goto(state.index - 1)}
                aria-label="Previous question"
              >
                <ChevronLeft aria-hidden />
                <span className="hidden sm:inline">Previous</span>
              </Button>

              {/* Question dots */}
              <div
                className="flex flex-1 items-center justify-center gap-0.5 overflow-x-auto"
                role="list"
                aria-label="Question progress"
              >
                {questions.map((q, i) => {
                  const a = state.answers[q.assessment_question_id];
                  const answered = a
                    ? "selected" in a
                      ? a.selected.length > 0
                      : "transcript" in a
                        ? a.transcript.trim().length > 0
                        : (a as CodingAnswer).code.trim().length > 0
                    : false;
                  const isCurrent = i === state.index;
                  return (
                    <button
                      key={q.assessment_question_id}
                      role="listitem"
                      onClick={() => meta.allow_backtrack ? goto(i) : undefined}
                      disabled={!meta.allow_backtrack && i !== state.index}
                      aria-label={`Question ${i + 1}${answered ? ", answered" : ""}`}
                      aria-current={isCurrent ? "step" : undefined}
                      className={cn(
                        "flex h-6 w-6 shrink-0 items-center justify-center rounded-full transition-all duration-fast",
                        meta.allow_backtrack && i !== state.index
                          ? "cursor-pointer hover:bg-muted"
                          : "cursor-default",
                      )}
                    >
                      <span
                        className={cn(
                          "block rounded-full transition-all duration-fast",
                          isCurrent
                            ? "h-2.5 w-2.5 bg-primary ring-2 ring-primary/30"
                            : answered
                              ? "h-2 w-2 bg-ai"
                              : "h-2 w-2 bg-border",
                        )}
                      />
                    </button>
                  );
                })}
              </div>

              {/* Clear */}
              <Button
                variant="ghost"
                size="sm"
                disabled={!currentAnswer}
                onClick={clearCurrentAnswer}
                aria-label="Clear current answer"
                className="shrink-0 text-muted-foreground"
              >
                <X aria-hidden />
                <span className="hidden sm:inline">Clear</span>
              </Button>

              {/* Next / Submit */}
              {state.index < questions.length - 1 ? (
                <Button
                  size="sm"
                  disabled={proctor.secondsLeft === 0}
                  onClick={() => goto(state.index + 1)}
                  aria-label="Next question"
                >
                  <span className="hidden sm:inline">Next</span>
                  <ChevronRight aria-hidden />
                </Button>
              ) : (
                <Button
                  size="sm"
                  disabled={proctor.secondsLeft === 0}
                  onClick={() => setConfirming("submit")}
                >
                  <Send aria-hidden />
                  <span className="hidden sm:inline">Submit</span>
                </Button>
              )}
            </div>
          </div>

          {/* Minor displays — floating camera PiPs */}
          <CameraPip
            stream={cameraSetup.stream}
            phoneConnected={cameraSetup.phoneConnected}
          />
        </div>
      )}
    </div>
  );
}
