"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import {
  Bookmark,
  ChevronLeft,
  ChevronRight,
  Clock,
  HelpCircle,
  Maximize,
  Pause,
  Send,
  ShieldAlert,
  TriangleAlert,
  X,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { ProctorBanner } from "@/components/assessments/proctor-banner";
import { ProctorPreflight } from "@/components/assessments/proctor-preflight";
import { MCQQuestion } from "@/components/shared/mcq-question";
import { CodingQuestion } from "@/components/assessments/coding-question";
import { TranscriptInput } from "@/components/assessments/transcript-input";
import { SectionSidebar } from "@/components/assessments/section-sidebar";
import { SectionTabs } from "@/components/assessments/section-tabs";
import { QuestionPalette } from "@/components/assessments/question-palette";
import { useProctor } from "@/lib/assessments/use-proctor";
import { useCameraSetup } from "@/lib/assessments/use-camera-setup";
import {
  useAnswers,
  isAnswered,
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
import {
  isMCQQuestion,
  isSubjectiveQuestion,
  SESSION_SUPERSEDED_MESSAGE,
  QUESTION_TYPE_LABELS,
} from "@/lib/assessments/types";
import { cn } from "@/lib/utils";
import type { AttemptPayload, QuestionSection, StudentQuestion } from "@/lib/assessments/types";

function formatSecondsLeft(total: number): string {
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  if (h > 0) return `${h}:${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
  return `${m}:${s.toString().padStart(2, "0")}`;
}

interface TestRunnerProps {
  payload: AttemptPayload;
}

type Stage = "camera" | "active";
type Confirming = "none" | "submit" | "exit" | "rules" | "superseded";

// All UI state lives in two useState calls; answer/nav/timing state in hooks.
export function TestRunner({ payload }: TestRunnerProps) {
  const { attempt, questions: rawQuestions, proctoring, meta, session_token: sessionToken } = payload;
  const router = useRouter();

  // Group questions by type (MCQ / Coding / Subjective) so the take page can
  // present them as jumpable sections, like a leetcode-style test runner.
  // Stable grouping by type, preserving each type's original position order —
  // no backend change needed since `type` already exists per question.
  const orderedQuestions = React.useMemo(() => {
    const groups = new Map<StudentQuestion["type"], StudentQuestion[]>();
    for (const q of rawQuestions) {
      const arr = groups.get(q.type);
      if (arr) arr.push(q);
      else groups.set(q.type, [q]);
    }
    return Array.from(groups.values()).flat();
  }, [rawQuestions]);

  const sections = React.useMemo(() => {
    const out: Omit<QuestionSection, "answeredCount">[] = [];
    orderedQuestions.forEach((q, i) => {
      const last = out[out.length - 1];
      if (last?.type === q.type) last.count += 1;
      else out.push({ type: q.type, label: QUESTION_TYPE_LABELS[q.type], startIndex: i, count: 1 });
    });
    return out;
  }, [orderedQuestions]);

  const { state, dispatch, answeredCount, markedCount } = useAnswers(orderedQuestions);
  const cameraSetup = useCameraSetup(proctoring.require_camera);

  const [stage, setStage] = React.useState<Stage>("camera");
  const [confirming, setConfirming] = React.useState<Confirming>("none");

  const resultHref = ROUTES.assessmentResult(attempt.id);
  const submittedRef = React.useRef(false);
  const supersededRef = React.useRef(false);
  const { stopStream } = cameraSetup;

  const finishTo = React.useCallback(
    (message: string) => {
      toast(message);
      router.push(resultHref);
    },
    [router, resultHref],
  );

  // Every mutating action can come back superseded (another device/tab opened
  // this same attempt). Once that happens, lock the UI — nothing further
  // should be written from this window — and never let it be dismissed.
  const markSupersededIfNeeded = React.useCallback((error: string | undefined) => {
    if (error !== SESSION_SUPERSEDED_MESSAGE || supersededRef.current) return false;
    supersededRef.current = true;
    setConfirming("superseded");
    return true;
  }, []);

  // Returns the in-flight save so callers that must guarantee persistence
  // before proceeding (submit) can await it; goto() fires-and-forgets it.
  const flush = React.useCallback(
    async (qid: string, value: AnswerValue | undefined) => {
      if (!value) return;
      const res =
        "transcript" in value
          ? await saveAnswerAction(attempt.id, sessionToken, qid, null, 0, value.transcript)
          : await saveAnswerAction(attempt.id, sessionToken, qid, value, 0);
      markSupersededIfNeeded(res.error);
    },
    [attempt.id, markSupersededIfNeeded, sessionToken],
  );

  const current = orderedQuestions[state.index];
  const currentAnswer = current ? state.answers[current.assessment_question_id] : undefined;
  const isCurrentMarked = current
    ? (state.markedForReview[current.assessment_question_id] ?? false)
    : false;

  const submit = React.useCallback(
    async (reason: string) => {
      if (submittedRef.current || supersededRef.current) return;
      submittedRef.current = true;
      // Flush the currently-displayed answer first — without this, an answer
      // entered on the last question and submitted without navigating away
      // was never persisted to the server before grading.
      if (current) {
        await flush(current.assessment_question_id, state.answers[current.assessment_question_id]);
      }
      if (supersededRef.current) return;
      dispatch({ kind: "submitting", value: true });
      const res = await submitAttemptAction(attempt.id, sessionToken);
      if (!res.ok) {
        submittedRef.current = false;
        dispatch({ kind: "submitting", value: false });
        if (!markSupersededIfNeeded(res.error)) toast.error(res.error ?? "Could not submit.");
        return;
      }
      stopStream();
      if (document.fullscreenElement) void document.exitFullscreen().catch(() => undefined);
      finishTo(reason);
    },
    [attempt.id, current, dispatch, finishTo, flush, markSupersededIfNeeded, sessionToken, state.answers, stopStream],
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
        sessionToken,
        event.type,
        event.severity,
        event.metadata,
      );
      if (markSupersededIfNeeded(res.error)) return;
      if (res.autoSubmitted)
        void submit("Your test was submitted automatically due to a policy violation.");
    },
    onTimeUp: () => void submit("Time is up — your test was submitted."),
    onAutoSubmit: () => void submit("Your test was submitted because you exited fullscreen."),
  });

  const clearCurrentAnswer = React.useCallback(() => {
    if (!current) return;
    const qid = current.assessment_question_id;
    dispatch({ kind: "clearAnswer", qid });
    if (isMCQQuestion(current)) {
      void saveAnswerAction(attempt.id, sessionToken, qid, { selected: [] }, 0).then((res) =>
        markSupersededIfNeeded(res.error),
      );
    } else if (isSubjectiveQuestion(current)) {
      void saveAnswerAction(attempt.id, sessionToken, qid, null, 0, "").then((res) =>
        markSupersededIfNeeded(res.error),
      );
    }
  }, [attempt.id, current, dispatch, markSupersededIfNeeded, sessionToken]);

  const goto = (index: number) => {
    if (current)
      void flush(current.assessment_question_id, state.answers[current.assessment_question_id]);
    dispatch({ kind: "goto", index });
  };

  if (!current) {
    return (
      <div className="fixed inset-0 z-modal flex items-center justify-center bg-background">
        <p className="text-muted-foreground">This assessment has no questions.</p>
      </div>
    );
  }

  // Coding questions get a full-bleed, non-scrolling column so the resizable
  // panels (see CodingQuestion) can claim the entire available viewport height
  // instead of being boxed into page-container's centered max-w-7xl column —
  // that centering makes sense for a reading-width MCQ/subjective card, but
  // for a LeetCode-style editor it just wastes width and forces a small fixed
  // panel height inside an outer page scroll.
  const isCoding = !isMCQQuestion(current) && !isSubjectiveQuestion(current);

  const progressPct = orderedQuestions.length > 0 ? (answeredCount / orderedQuestions.length) * 100 : 0;
  const sectionsWithProgress: QuestionSection[] = sections.map((s) => ({
    ...s,
    answeredCount: orderedQuestions
      .slice(s.startIndex, s.startIndex + s.count)
      .filter((q) => isAnswered(state.answers[q.assessment_question_id])).length,
  }));

  return (
    <div className="fixed inset-0 z-modal bg-background">

      {/* Superseded-session lock — another device/tab opened this attempt.
          Covers everything, including the exit/submit dialogs, and is never
          dismissible: this window can no longer write to the attempt. */}
      {confirming === "superseded" && (
        <div className="fixed inset-0 z-toast flex items-center justify-center bg-background p-4">
          <div className="w-full max-w-sm rounded-2xl border border-border bg-card p-6 text-center shadow-raised">
            <span className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-destructive/10">
              <ShieldAlert aria-hidden className="h-6 w-6 text-destructive" />
            </span>
            <h2 className="text-lg font-semibold">Session moved to another device</h2>
            <p className="mt-2 text-sm text-muted-foreground">
              This attempt was reopened on another device or browser tab, which is now the
              active session. This window can no longer answer or submit — your progress up to
              the switch has been saved.
            </p>
          </div>
        </div>
      )}

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
        <div className="relative flex h-full flex-col">

          {/* Zone 1: ProctorBanner — shrink-0 at top */}
          <ProctorBanner
            answered={answeredCount}
            secondsLeft={proctor.secondsLeft}
            submitDisabled={state.submitting || proctor.secondsLeft === 0}
            total={orderedQuestions.length}
            violations={proctor.violations}
            onExit={() => setConfirming("exit")}
            onHelp={() => setConfirming("rules")}
            onSubmit={() => setConfirming("submit")}
          />

          {/* Zone 2: Question content + right question palette */}
          <div className="relative flex flex-1 overflow-hidden">

            {/* Exit confirmation overlay — covers question area + palette */}
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
                      className="flex-1"
                      variant="outline"
                      onClick={() => setConfirming("none")}
                    >
                      Stay in test
                    </Button>
                    <Button
                      className="flex-1"
                      variant="destructive"
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

            {/* Proctoring rules overlay — opened from the help icon in the banner */}
            {confirming === "rules" && (
              <div className="absolute inset-0 z-overlay flex items-center justify-center bg-background/80 p-4 backdrop-blur-sm">
                <div className="w-full max-w-sm rounded-2xl border border-border bg-card p-6 shadow-raised">
                  <div className="mb-4 flex flex-col items-center gap-3 text-center">
                    <span className="flex h-12 w-12 items-center justify-center rounded-full bg-primary/10">
                      <HelpCircle aria-hidden className="h-6 w-6 text-primary" />
                    </span>
                    <h2 className="text-lg font-semibold">Proctoring rules</h2>
                  </div>
                  <ul className="flex flex-col gap-1.5 text-sm text-muted-foreground">
                    {proctoring.require_camera && <li>Your camera is monitored during the test</li>}
                    {proctoring.allow_secondary_camera && (
                      <li>A secondary phone camera may also be active</li>
                    )}
                    {proctoring.require_fullscreen && (
                      <li>Fullscreen is required — leaving it triggers a flag</li>
                    )}
                    {proctoring.block_copy_paste && <li>Copy, paste, and right-click are blocked</li>}
                    {proctoring.max_tab_switches > 0 && (
                      <li>
                        Max {proctoring.max_tab_switches} tab switch
                        {proctoring.max_tab_switches !== 1 ? "es" : ""} allowed
                      </li>
                    )}
                    {proctoring.block_devtools && (
                      <li>Developer tools must stay closed during the test</li>
                    )}
                    {!proctoring.require_camera &&
                      !proctoring.allow_secondary_camera &&
                      !proctoring.require_fullscreen &&
                      !proctoring.block_copy_paste &&
                      proctoring.max_tab_switches === 0 &&
                      !proctoring.block_devtools && <li>No special proctoring rules for this test.</li>}
                  </ul>
                  <Button className="mt-5 w-full" variant="outline" onClick={() => setConfirming("none")}>
                    Close
                  </Button>
                </div>
              </div>
            )}

            {/* Submit confirmation overlay — covers question area + palette */}
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
                        {answeredCount} of {orderedQuestions.length} answered.{" "}
                        {answeredCount < orderedQuestions.length &&
                          `${orderedQuestions.length - answeredCount} question${
                            orderedQuestions.length - answeredCount !== 1 ? "s" : ""
                          } will be left blank.`}
                      </p>
                    </div>
                  </div>
                  <div className="flex gap-3">
                    <Button
                      className="flex-1"
                      disabled={state.submitting}
                      variant="outline"
                      onClick={() => setConfirming("none")}
                    >
                      Keep reviewing
                    </Button>
                    <Button
                      className="flex-1"
                      disabled={state.submitting || proctor.secondsLeft === 0}
                      onClick={() => void submit("Test submitted. Good job!")}
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

            {/* Left panel — section navigator (desktop only) */}
            <SectionSidebar currentType={current.type} sections={sectionsWithProgress} onJump={goto} />

            {/* Scrollable question content — coding gets a full-bleed, non-scrolling
                column (its resizable panels scroll internally); MCQ/subjective keep
                the centered, page-scrolling reading column. */}
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
                <SectionTabs currentType={current.type} sections={sectionsWithProgress} onJump={goto} />

                {/* Question meta — select-none prevents students from copy-pasting
                    the question title and type labels out of the test. */}
                <div className={cn("flex select-none flex-col gap-2", isCoding ? "mb-3 shrink-0" : "mb-5")}>
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div className="flex items-baseline gap-1.5">
                      <span className="text-2xl font-bold tabular-nums">
                        Q{state.index + 1}
                      </span>
                      <span className="text-base text-muted-foreground">
                        of {orderedQuestions.length}
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
                          onClick={clearCurrentAnswer}
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
                            attempt.id,
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
                      attemptId={attempt.id}
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
                      onSuperseded={() => markSupersededIfNeeded(SESSION_SUPERSEDED_MESSAGE)}
                    />
                  </div>
                )}
              </div>
            </div>

            {/* Right panel — question palette (desktop only, collapsible) */}
            <QuestionPalette
              allowBacktrack={meta.allow_backtrack}
              answeredCount={answeredCount}
              answers={state.answers}
              cameraStream={cameraSetup.stream}
              currentIndex={state.index}
              markedCount={markedCount}
              markedForReview={state.markedForReview}
              phoneConnected={cameraSetup.phoneConnected}
              proctoring={proctoring}
              progressPct={progressPct}
              questions={orderedQuestions}
              onJump={goto}
            />
          </div>

          {/* Zone 3: Previous/Next navigation — Submit lives in the top banner now,
              so this line is just prev/next (no position count, per design). */}
          <div className="shrink-0 border-t border-border bg-background/95 px-4 py-3 backdrop-blur-sm sm:px-6">
            <div className="flex items-center justify-between gap-3">
              <Button
                aria-label="Previous question"
                disabled={state.index === 0 || !meta.allow_backtrack}
                size="sm"
                variant="outline"
                onClick={() => goto(state.index - 1)}
              >
                <ChevronLeft aria-hidden />
                <span className="hidden sm:inline">Previous</span>
              </Button>
              <Button
                aria-label="Next question"
                disabled={proctor.secondsLeft === 0 || state.index === orderedQuestions.length - 1}
                size="sm"
                onClick={() => goto(state.index + 1)}
              >
                <span className="hidden sm:inline">Next</span>
                <ChevronRight aria-hidden />
              </Button>
            </div>
          </div>

          {/* Fullscreen-exit overlay — fully opaque so questions are never visible
              while the student is outside fullscreen. Content and timer behaviour
              vary by the assessment's configured fullscreen_exit_action. */}
          {proctoring.require_fullscreen && proctor.isFullscreenViolation && (
            <div className="absolute inset-0 z-overlay flex items-center justify-center bg-background p-4">
              <div className="w-full max-w-sm rounded-2xl border border-border bg-card p-6 text-center shadow-raised">
                <span className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-primary/10">
                  <Pause aria-hidden className="h-6 w-6 text-primary" />
                </span>
                {proctoring.fullscreen_exit_action === "continue" ? (
                  <>
                    <h2 className="text-lg font-semibold">Questions Hidden</h2>
                    <p className="mt-2 text-sm text-muted-foreground">
                      You exited fullscreen. Questions are hidden but the timer is
                      still running.
                    </p>
                    <div className="mt-4 flex items-center justify-center gap-1.5 font-mono text-2xl font-bold tabular-nums text-destructive">
                      <Clock aria-hidden className="h-5 w-5" />
                      {formatSecondsLeft(proctor.secondsLeft)}
                    </div>
                  </>
                ) : (
                  <>
                    <h2 className="text-lg font-semibold">Test Paused</h2>
                    <p className="mt-2 text-sm text-muted-foreground">
                      You exited fullscreen. The timer is frozen — return to
                      fullscreen to continue.
                    </p>
                    <div className="mt-4 flex items-center justify-center gap-1.5 font-mono text-2xl font-bold tabular-nums text-primary">
                      <Clock aria-hidden className="h-5 w-5" />
                      {formatSecondsLeft(proctor.secondsLeft)}
                    </div>
                  </>
                )}
                <Button className="mt-5 w-full gap-2" onClick={proctor.requestFullscreen}>
                  <Maximize aria-hidden />
                  Return to Fullscreen
                </Button>
                <p className="mt-3 text-xs text-destructive">
                  Exiting fullscreen has been recorded as a violation.
                </p>
              </div>
            </div>
          )}

          {/* DevTools blocking overlay — fully opaque so question content cannot
              be read in the Elements panel. Appears on top of the pause overlay
              (later in DOM) so both violations are handled simultaneously. */}
          {proctoring.block_devtools && proctor.devToolsOpen && (
            <div className="absolute inset-0 z-overlay flex items-center justify-center bg-background p-4">
              <div className="w-full max-w-sm rounded-2xl border border-destructive/30 bg-card p-6 text-center shadow-raised">
                <span className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-destructive/10">
                  <ShieldAlert aria-hidden className="h-6 w-6 text-destructive" />
                </span>
                <h2 className="text-lg font-semibold">Developer Tools Detected</h2>
                <p className="mt-2 text-sm text-muted-foreground">
                  Close the developer tools panel to resume your test. This event
                  has been recorded and flagged.
                </p>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
