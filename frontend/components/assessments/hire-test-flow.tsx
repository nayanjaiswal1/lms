"use client";

import * as React from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { CheckCircle, XCircle } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { startPublicAttemptAction, submitPublicAttemptAction } from "@/lib/public/actions";
import type { PublicTestInfo, PublicQuestion } from "@/lib/server/public";

// ─── Types ────────────────────────────────────────────────────────────────────

interface Props {
  code: string;
  testInfo: PublicTestInfo;
}

type FlowState =
  | { stage: "landing" }
  | { stage: "taking"; token: string; name: string; questions: PublicQuestion[]; meta: SessionMeta }
  | { stage: "done"; name: string; percentage: number; passed: boolean; score: number; maxScore: number };

interface SessionMeta {
  title: string;
  duration_minutes: number;
  allow_backtrack: boolean;
  total_points: number;
  pass_percentage: number;
}

// ─── Landing form ─────────────────────────────────────────────────────────────

const LandingSchema = z.object({
  name: z.string().min(2, "Name must be at least 2 characters."),
  email: z.string().email("Enter a valid email."),
  phone: z.string().optional(),
});
type LandingFormData = z.infer<typeof LandingSchema>;

function LandingForm({
  code,
  onStarted,
}: {
  code: string;
  onStarted: (data: { token: string; name: string; questions: PublicQuestion[]; meta: SessionMeta }) => void;
}) {
  const form = useForm<LandingFormData>({
    resolver: zodResolver(LandingSchema),
    defaultValues: { name: "", email: "", phone: "" },
  });

  const onSubmit = async (data: LandingFormData) => {
    const res = await startPublicAttemptAction(code, {
      name: data.name,
      email: data.email,
      phone: data.phone || undefined,
    });
    if (!res.ok || !res.data) {
      toast.error(res.error ?? "Could not start the test.");
      return;
    }
    onStarted({
      token: res.data.session_token,
      name: data.name,
      questions: res.data.questions,
      meta: res.data.meta,
    });
  };

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormInputField control={form.control} label="Full Name" name="name" placeholder="Jane Smith" />
        <FormInputField control={form.control} label="Email" name="email" placeholder="jane@company.com" type="email" />
        <FormInputField control={form.control} label="Phone (optional)" name="phone" placeholder="+1 555 000 0000" />
        <Button className="w-full" disabled={form.formState.isSubmitting} size="lg" type="submit">
          {form.formState.isSubmitting ? "Starting…" : "Start Test"}
        </Button>
      </form>
    </Form>
  );
}

// ─── Test runner ──────────────────────────────────────────────────────────────

function TestRunner({
  code,
  token,
  questions,
  meta,
  onDone,
}: {
  code: string;
  token: string;
  questions: PublicQuestion[];
  meta: SessionMeta;
  onDone: (result: { percentage: number; passed: boolean; score: number; maxScore: number }) => void;
}) {
  // answers: {assessment_question_id: selected_option_ids[]}
  const [answers, setAnswers] = React.useState<Record<string, string[]>>({});
  const [submitting, setSubmitting] = React.useState(false);
  const [index, setIndex] = React.useState(0);
  const q = questions[index];

  const toggle = (aqId: string, optionId: string, multiple: boolean) => {
    setAnswers((prev) => {
      const current = prev[aqId] ?? [];
      if (multiple) {
        return {
          ...prev,
          [aqId]: current.includes(optionId) ? current.filter((id) => id !== optionId) : [...current, optionId],
        };
      }
      return { ...prev, [aqId]: [optionId] };
    });
  };

  const handleSubmit = async () => {
    setSubmitting(true);
    const res = await submitPublicAttemptAction(code, token, answers);
    setSubmitting(false);
    if (!res.ok || !res.data) {
      toast.error(res.error ?? "Could not submit. Try again.");
      return;
    }
    onDone({
      percentage: res.data.percentage,
      passed: res.data.passed,
      score: res.data.score,
      maxScore: res.data.max_score,
    });
  };

  if (!q) return null;

  const isMultiple = q.content.multiple ?? false;
  const selected = answers[q.assessment_question_id] ?? [];
  const answeredCount = Object.values(answers).filter((a) => a.length > 0).length;

  return (
    <div className="flex min-h-dvh flex-col">
      {/* Header */}
      <header className="sticky top-0 z-sticky border-b border-border bg-background/95 backdrop-blur">
        <div className="page-container flex items-center justify-between py-3">
          <div className="flex flex-col gap-0.5">
            <span className="text-sm font-semibold">{meta.title}</span>
            <span className="text-xs text-muted-foreground">
              {answeredCount} / {questions.length} answered
            </span>
          </div>
          <Button disabled={submitting} size="sm" onClick={handleSubmit}>
            {submitting ? "Submitting…" : "Submit Test"}
          </Button>
        </div>
      </header>

      <main className="page-container flex flex-1 flex-col gap-6 py-8">
        {/* Question navigation */}
        <div className="flex flex-wrap gap-2">
          {questions.map((question, i) => {
            const isAnswered = (answers[question.assessment_question_id]?.length ?? 0) > 0;
            return (
              <button
                className={`flex h-8 w-8 items-center justify-center rounded-md border text-sm font-medium transition-colors duration-fast ease-smooth ${
                  i === index
                    ? "border-primary bg-primary text-primary-foreground"
                    : isAnswered
                      ? "border-primary/30 bg-primary/10 text-primary"
                      : "border-border bg-muted text-muted-foreground hover:border-primary/50"
                }`}
                key={question.assessment_question_id}
                type="button"
                onClick={() => setIndex(i)}
              >
                {i + 1}
              </button>
            );
          })}
        </div>

        {/* Current question */}
        <div className="card-base p-6">
          <div className="mb-1 flex items-center justify-between gap-2">
            <span className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
              Question {index + 1} of {questions.length}
            </span>
            <span className="text-xs text-muted-foreground">{q.points} pt{q.points !== 1 ? "s" : ""}</span>
          </div>
          <p className="mt-3 text-base font-medium leading-relaxed">{q.content.prompt}</p>
          {isMultiple && (
            <p className="mt-1 text-xs text-muted-foreground">Select all that apply.</p>
          )}

          <div className="mt-5 flex flex-col gap-3">
            {(q.content.options ?? []).map((opt) => {
              const isSelected = selected.includes(opt.id);
              return (
                <button
                  className={`flex items-start gap-3 rounded-lg border p-4 text-left text-sm transition-colors duration-fast ease-smooth ${
                    isSelected
                      ? "border-primary bg-primary/10 font-medium text-foreground"
                      : "border-border bg-card hover:border-primary/40 hover:bg-muted"
                  }`}
                  key={opt.id}
                  type="button"
                  onClick={() => toggle(q.assessment_question_id, opt.id, isMultiple)}
                >
                  <span
                    className={`mt-0.5 flex h-4 w-4 shrink-0 items-center justify-center rounded-full border ${
                      isSelected ? "border-primary bg-primary" : "border-muted-foreground"
                    }`}
                    aria-hidden
                  >
                    {isSelected && <span className="h-2 w-2 rounded-full bg-primary-foreground" />}
                  </span>
                  {opt.text}
                </button>
              );
            })}
          </div>
        </div>

        {/* Prev / Next */}
        <div className="flex justify-between gap-3">
          <Button
            disabled={index === 0}
            size="sm"
            variant="outline"
            onClick={() => setIndex((i) => i - 1)}
          >
            Previous
          </Button>
          {index < questions.length - 1 ? (
            <Button size="sm" variant="outline" onClick={() => setIndex((i) => i + 1)}>
              Next
            </Button>
          ) : (
            <Button disabled={submitting} size="sm" onClick={handleSubmit}>
              {submitting ? "Submitting…" : "Submit Test"}
            </Button>
          )}
        </div>
      </main>
    </div>
  );
}

// ─── Result view ──────────────────────────────────────────────────────────────

function ResultView({
  name,
  percentage,
  passed,
  score,
  maxScore,
}: {
  name: string;
  percentage: number;
  passed: boolean;
  score: number;
  maxScore: number;
}) {
  return (
    <main className="flex min-h-dvh items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="card-base flex flex-col items-center gap-6 p-8 text-center">
          {passed ? (
            <CheckCircle aria-hidden className="h-16 w-16 text-primary" />
          ) : (
            <XCircle aria-hidden className="h-16 w-16 text-destructive" />
          )}
          <div>
            <p className="text-muted-foreground">Well done, {name}!</p>
            <h1 className="mt-1 text-3xl font-bold tabular-nums">
              {percentage.toFixed(0)}%
            </h1>
            <p className={`mt-1 font-semibold ${passed ? "text-primary" : "text-destructive"}`}>
              {passed ? "Passed" : "Not Passed"}
            </p>
          </div>
          <div className="grid w-full grid-cols-2 gap-3">
            <div className="card-base p-4">
              <p className="text-2xl font-bold tabular-nums">{score.toFixed(0)}</p>
              <p className="text-xs text-muted-foreground">Score</p>
            </div>
            <div className="card-base p-4">
              <p className="text-2xl font-bold tabular-nums">{maxScore.toFixed(0)}</p>
              <p className="text-xs text-muted-foreground">Max score</p>
            </div>
          </div>
          <p className="text-sm text-muted-foreground">
            Your result has been recorded. You may close this window.
          </p>
        </div>
      </div>
    </main>
  );
}

// ─── Root flow orchestrator ───────────────────────────────────────────────────

export function HireTestFlow({ code, testInfo }: Props) {
  const [flow, setFlow] = React.useState<FlowState>({ stage: "landing" });

  if (flow.stage === "done") {
    return (
      <ResultView
        maxScore={flow.maxScore}
        name={flow.name}
        passed={flow.passed}
        percentage={flow.percentage}
        score={flow.score}
      />
    );
  }

  if (flow.stage === "taking") {
    return (
      <TestRunner
        code={code}
        meta={flow.meta}
        questions={flow.questions}
        token={flow.token}
        onDone={(result) =>
          setFlow({ stage: "done", name: flow.name, ...result })
        }
      />
    );
  }

  return (
    <main className="flex min-h-dvh items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="card-base p-8">
          <div className="mb-6 text-center">
            <h1 className="text-2xl font-bold tracking-tight">{testInfo.title}</h1>
            {testInfo.description && (
              <p className="mt-2 text-muted-foreground">{testInfo.description}</p>
            )}
            <div className="mt-4 flex justify-center gap-6 text-sm text-muted-foreground">
              <span>{testInfo.question_count} question{testInfo.question_count !== 1 ? "s" : ""}</span>
              <span>{testInfo.duration_minutes} min</span>
              <span>Pass: {testInfo.pass_percentage}%</span>
            </div>
          </div>
          <LandingForm
            code={code}
            onStarted={(data) =>
              setFlow({
                stage: "taking",
                token: data.token,
                name: data.name,
                questions: data.questions,
                meta: data.meta,
              })
            }
          />
        </div>
      </div>
    </main>
  );
}
