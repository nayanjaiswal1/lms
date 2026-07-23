"use client";

import { useActionState, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Clock } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { CodeEditor } from "@/components/shared/code-editor";
import { MCQQuestion } from "@/components/shared/mcq-question";
import { PromptRenderer } from "@/components/shared/prompt-renderer";
import { submitFinalTestAttemptAction } from "@/lib/courses/actions";
import type { StudentFinalTest } from "@/lib/server/courses";
import type { ActionResult } from "@/lib/server/api";
import type { SubmitFinalTestAttemptResult } from "@/lib/server/courses";
import ROUTES from "@/lib/routes";

interface Props {
  courseId: string;
  courseSlug: string;
  courseTitle: string;
  finalTest: StudentFinalTest;
}

type McqAnswer = { selected: string[] };
type CodingAnswer = { language: string; code: string };
type AnswerValue = McqAnswer | CodingAnswer;

function formatClock(totalSeconds: number): string {
  const m = Math.floor(totalSeconds / 60);
  const s = totalSeconds % 60;
  return `${m}:${s.toString().padStart(2, "0")}`;
}

export function FinalTestClient({ courseId, courseSlug, courseTitle, finalTest }: Props) {
  const router = useRouter();
  const [answers, setAnswers] = useState<Record<string, AnswerValue>>({});
  const [secondsLeft, setSecondsLeft] = useState(finalTest.time_limit_minutes * 60);

  const [result, submitAction, pending] = useActionState<
    ActionResult<SubmitFinalTestAttemptResult> | null,
    undefined
  >(async () => {
    const res = await submitFinalTestAttemptAction(courseId, answers);
    if (!res.ok) {
      toast.error(res.error ?? "Could not submit your attempt.");
      return res;
    }
    if (res.data?.certificate) {
      toast.success("Passed! Certificate issued.");
      router.push(ROUTES.certificate(res.data.certificate.cert_uuid));
    } else {
      toast.info(`Scored ${res.data?.attempt.score}% — needed ${finalTest.passing_score_percent}% to pass.`);
      router.push(ROUTES.course(courseSlug));
    }
    return res;
  }, null);

  // Countdown timer — browser-clock side effect with no server-component
  // alternative, same justification as components/assessments/eval-poller.tsx.
  // Auto-submits once time runs out so a stalled tab can't dodge the limit.
  useEffect(() => {
    if (pending || secondsLeft <= 0) return;
    const id = setInterval(() => setSecondsLeft((s) => Math.max(0, s - 1)), 1000);
    return () => clearInterval(id);
  }, [pending, secondsLeft]);

  useEffect(() => {
    if (secondsLeft === 0 && !pending && !result) {
      toast.warning("Time's up — submitting your answers.");
      submitAction(undefined);
    }
  }, [secondsLeft, pending, result, submitAction]);

  function setMcqAnswer(questionId: string, optionId: string, multiple: boolean) {
    setAnswers((prev) => {
      const current = (prev[questionId] as McqAnswer | undefined)?.selected ?? [];
      const next = multiple
        ? current.includes(optionId) ? current.filter((id) => id !== optionId) : [...current, optionId]
        : [optionId];
      return { ...prev, [questionId]: { selected: next } };
    });
  }

  function setCodingAnswer(questionId: string, language: string, code: string) {
    setAnswers((prev) => ({ ...prev, [questionId]: { language, code } }));
  }

  const totalPoints = finalTest.questions.reduce((sum, q) => sum + q.points, 0);
  const timeCritical = secondsLeft <= 60;

  return (
    <div className="flex flex-col gap-8">
      <div className="page-header sticky top-16 z-sticky rounded-lg border border-border bg-card px-4 py-3">
        <div>
          <h1 className="text-xl font-semibold">{courseTitle} — Final Test</h1>
          <p className="text-xs text-muted-foreground">
            {finalTest.questions.length} question{finalTest.questions.length === 1 ? "" : "s"} · {totalPoints} points ·
            Attempt {finalTest.attempts_used + 1} of {finalTest.max_attempts}
          </p>
        </div>
        <div className={`flex items-center gap-2 font-mono text-lg font-semibold ${timeCritical ? "text-destructive" : "text-foreground"}`}>
          <Clock aria-hidden className="h-5 w-5" />
          {formatClock(secondsLeft)}
        </div>
      </div>

      {finalTest.questions.map((q, i) => (
        <div className="card-base flex flex-col gap-4 p-6" key={q.id}>
          <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
            Question {i + 1} · {q.points} pt{q.points === 1 ? "" : "s"}
          </p>

          {q.type === "mcq" && q.mcq && (
            <MCQQuestion
              content={q.mcq}
              selected={(answers[q.id] as McqAnswer | undefined)?.selected ?? []}
              onToggle={(optionId, multiple) => setMcqAnswer(q.id, optionId, multiple)}
            />
          )}

          {q.type === "coding" && q.coding && (
            <div className="flex flex-col gap-3">
              <PromptRenderer text={q.coding.prompt} />
              <CodingAnswerEditor
                content={q.coding}
                value={answers[q.id] as CodingAnswer | undefined}
                onChange={(language, code) => setCodingAnswer(q.id, language, code)}
              />
            </div>
          )}
        </div>
      ))}

      <div className="flex justify-end border-t border-border pt-4">
        <Button disabled={pending} size="lg" onClick={() => submitAction(undefined)}>
          {pending ? "Submitting…" : "Submit Final Test"}
        </Button>
      </div>
    </div>
  );
}

interface CodingAnswerEditorProps {
  content: StudentFinalTest["questions"][number]["coding"];
  value: CodingAnswer | undefined;
  onChange: (language: string, code: string) => void;
}

function CodingAnswerEditor({ content, value, onChange }: CodingAnswerEditorProps) {
  if (!content) return null;
  const language = value?.language ?? content.languages[0] ?? "python";
  const code = value?.code ?? content.starter_code?.[language] ?? "";

  return (
    <div className="flex flex-col gap-2">
      {content.languages.length > 1 && (
        <Select value={language} onValueChange={(lang) => onChange(lang, content.starter_code?.[lang] ?? "")}>
          <SelectTrigger className="w-40">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {content.languages.map((lang) => (
              <SelectItem key={lang} value={lang}>{lang}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      )}
      <CodeEditor height="320px" language={language} value={code} onChange={(v) => onChange(language, v ?? "")} />
    </div>
  );
}
