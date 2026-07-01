import type { Metadata } from "next";
import Link from "next/link";
import { CheckCircle2, XCircle, Clock, Hourglass, Loader2 } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { EvaluationCard } from "@/components/assessments/evaluation-card";
import { EvalPoller } from "@/components/assessments/eval-poller";
import { RewardResultNotifier } from "@/components/rewards/reward-result-notifier";
import { getAttemptResult, getEvaluation } from "@/lib/server/assessments";
import ROUTES from "@/lib/routes";
import type { ReviewItem } from "@/lib/assessments/types";

export const metadata: Metadata = {
  title: "Assessment Result",
  robots: { index: false, follow: false },
};

interface PageProps {
  params: Promise<{ attemptId: string }>;
}

export default async function ResultPage({ params }: PageProps) {
  const { attemptId } = await params;
  const data = await getAttemptResult(attemptId);
  const { attempt } = data;

  const evaluating = attempt.status === "evaluating";
  const evalFailed = attempt.status === "eval_failed";
  const pending = attempt.status === "submitted" || evaluating;
  const passed = attempt.passed === true;
  const pct = attempt.percentage !== null ? Math.round(attempt.percentage) : 0;

  // Fetch evaluation when the attempt is fully evaluated — shows AI feedback.
  let evaluation = null;
  if (attempt.status === "evaluated") {
    evaluation = await getEvaluation(attemptId).catch(() => null);
  }
  const hasSubjectiveEval = evaluation !== null && evaluation.per_question.length > 0;

  return (
    <main className="page-container-sm py-10">
      <EvalPoller status={attempt.status} />
      <RewardResultNotifier result={attempt.reward_result ?? null} />
      <div className="card-raised flex flex-col items-center gap-4 p-8 text-center">
        {evaluating ? (
          <Loader2 aria-hidden className="h-12 w-12 animate-spin text-muted-foreground" />
        ) : pending ? (
          <Hourglass aria-hidden className="h-12 w-12 text-muted-foreground" />
        ) : evalFailed ? (
          <XCircle aria-hidden className="h-12 w-12 text-destructive" />
        ) : passed ? (
          <CheckCircle2 aria-hidden className="h-12 w-12 text-ai" />
        ) : (
          <XCircle aria-hidden className="h-12 w-12 text-destructive" />
        )}

        <div className="flex flex-col gap-1">
          <h1 className="text-3xl font-bold tabular-nums">
            {evaluating
              ? "Evaluating…"
              : pending
                ? "Submitted"
                : evalFailed
                  ? "Evaluation failed"
                  : `${pct}%`}
          </h1>
          <p className="text-muted-foreground">
            {evaluating
              ? "Your answers are being evaluated by AI. This takes about 1–2 minutes. Refresh to check."
              : pending
                ? "Your answers are awaiting evaluation. Check back shortly."
                : evalFailed
                  ? "AI evaluation could not complete. Your instructor has been notified."
                  : passed
                    ? "You passed this assessment."
                    : "You did not reach the pass mark."}
          </p>
        </div>

        {!pending && !evalFailed && !evaluating && (
          <div className="flex flex-wrap items-center justify-center gap-3 text-sm">
            <Badge variant={passed ? "default" : "destructive"}>{passed ? "Passed" : "Not passed"}</Badge>
            {attempt.score !== null && attempt.max_score !== null && (
              <span className="text-muted-foreground">
                {attempt.score} / {attempt.max_score} points
              </span>
            )}
            <span className="inline-flex items-center gap-1 text-muted-foreground">
              <Clock className="h-4 w-4" /> {Math.round(attempt.duration_seconds / 60)} min
            </span>
            {attempt.auto_submitted && <Badge variant="secondary">Auto-submitted</Badge>}
          </div>
        )}

        <div className="flex flex-wrap items-center justify-center gap-3">
          <Button asChild variant="outline">
            <Link href={ROUTES.ASSESSMENTS}>Back to assessments</Link>
          </Button>
          {(evaluating || pending) && (
            <Button asChild>
              <Link href={ROUTES.assessmentResult(attemptId)}>Refresh</Link>
            </Button>
          )}
        </div>
      </div>

      {data.show_review && data.review && data.review.length > 0 && (
        <section className="mt-8 flex flex-col gap-3">
          <h2 className="section-title">Review</h2>
          {data.review.map((item) => (
            <ReviewRow item={item} key={item.question_id} />
          ))}
        </section>
      )}

      {hasSubjectiveEval && evaluation && (
        <EvaluationCard evaluation={evaluation} />
      )}
    </main>
  );
}

function ReviewRow({ item }: { item: ReviewItem }) {
  const correct = item.is_correct === true;
  const ungraded = item.is_correct === null;
  return (
    <article className="card-base flex flex-col gap-2 p-5">
      <div className="flex items-start justify-between gap-3">
        <div className="flex items-center gap-2">
          {ungraded ? (
            <Hourglass aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
          ) : correct ? (
            <CheckCircle2 aria-hidden className="h-4 w-4 shrink-0 text-ai" />
          ) : (
            <XCircle aria-hidden className="h-4 w-4 shrink-0 text-destructive" />
          )}
          <h3 className="text-sm font-semibold">
            {item.position + 1}. {item.title}
          </h3>
        </div>
        <Badge variant="outline">
          {item.points_awarded}/{item.max_points}
        </Badge>
      </div>

      {item.type === "coding" && item.coding_result && (
        <p className="pl-6 text-xs text-muted-foreground">
          Tests passed {item.coding_result.tests_passed}/{item.coding_result.tests_total} · {item.coding_result.status}
        </p>
      )}

      {item.explanation && <p className="pl-6 text-sm text-muted-foreground">{item.explanation}</p>}
    </article>
  );
}
