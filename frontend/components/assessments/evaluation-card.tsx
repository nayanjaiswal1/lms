import { CheckCircle2, AlertTriangle, Lightbulb, TrendingUp } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import type { FullEvaluation, EvaluationRow } from "@/lib/assessments/types";

interface EvaluationCardProps {
  evaluation: FullEvaluation;
}

// EvaluationCard renders the AI evaluation for a completed subjective attempt.
// It shows the overall readiness score, 7-dimension breakdown, and per-question
// qualitative feedback. This is a Server Component — no interactivity needed.
export function EvaluationCard({ evaluation }: EvaluationCardProps) {
  const { overall, per_question } = evaluation;

  return (
    <section className="flex flex-col gap-6 mt-8">
      <h2 className="section-title">AI Evaluation</h2>

      {overall && <OverallPanel row={overall} />}

      {per_question.length > 0 && (
        <div className="flex flex-col gap-4">
          <h3 className="text-lg font-semibold">Per-question feedback</h3>
          {per_question.map((row, i) => (
            <QuestionPanel key={row.id} row={row} index={i} />
          ))}
        </div>
      )}
    </section>
  );
}

function OverallPanel({ row }: { row: EvaluationRow }) {
  const readiness = row.readiness_score ?? 0;
  const composite = row.composite_score ?? 0;

  return (
    <div className="card-raised flex flex-col gap-5 p-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-sm text-muted-foreground">Overall readiness</p>
          <p className="text-4xl font-bold tabular-nums">{Math.round(readiness)}%</p>
        </div>
        <div>
          <p className="text-sm text-muted-foreground">Composite score</p>
          <p className="text-4xl font-bold tabular-nums">{Math.round(composite)}</p>
        </div>
        {row.review_required && (
          <Badge variant="destructive">Under review</Badge>
        )}
      </div>

      {row.strengths.length > 0 && (
        <FeedbackList icon={<CheckCircle2 className="h-4 w-4 text-ai" aria-hidden />} label="Strengths" items={row.strengths} />
      )}
      {row.weaknesses.length > 0 && (
        <FeedbackList icon={<AlertTriangle className="h-4 w-4 text-destructive" aria-hidden />} label="Areas to improve" items={row.weaknesses} />
      )}
      {row.improvements.length > 0 && (
        <FeedbackList icon={<Lightbulb className="h-4 w-4 text-primary" aria-hidden />} label="Suggestions" items={row.improvements} />
      )}
    </div>
  );
}

function QuestionPanel({ row, index }: { row: EvaluationRow; index: number }) {
  const dims = [
    { key: "score_technical_accuracy", label: "Technical accuracy", value: row.score_technical_accuracy },
    { key: "score_completeness",        label: "Completeness",        value: row.score_completeness },
    { key: "score_communication",       label: "Communication",       value: row.score_communication },
    { key: "score_clarity",             label: "Clarity",             value: row.score_clarity },
    { key: "score_structure",           label: "Structure",           value: row.score_structure },
    { key: "score_confidence",          label: "Confidence",          value: row.score_confidence },
    { key: "score_seniority_alignment", label: "Seniority fit",       value: row.score_seniority_alignment },
  ];

  return (
    <article className="card-base flex flex-col gap-4 p-5">
      <div className="flex items-center justify-between gap-3">
        <h4 className="font-semibold">Question {index + 1}</h4>
        {row.composite_score !== null && (
          <div className="flex items-center gap-1 text-sm text-muted-foreground">
            <TrendingUp className="h-4 w-4" aria-hidden />
            {Math.round(row.composite_score)} / 100
          </div>
        )}
      </div>

      <div className="grid gap-2 sm:grid-cols-2">
        {dims.map((d) =>
          d.value !== null ? (
            <ScoreBar key={d.key} label={d.label} value={d.value} />
          ) : null,
        )}
      </div>

      {row.strengths.length > 0 && (
        <FeedbackList icon={<CheckCircle2 className="h-3 w-3 text-ai" aria-hidden />} label="Strengths" items={row.strengths} />
      )}
      {row.missing_concepts.length > 0 && (
        <FeedbackList icon={<AlertTriangle className="h-3 w-3 text-destructive" aria-hidden />} label="Missing concepts" items={row.missing_concepts} />
      )}
      {row.better_answer && (
        <div className="ai-surface rounded-[--radius-md] p-4">
          <p className="mb-1 text-xs font-semibold text-ai">Better answer</p>
          <p className="text-sm">{row.better_answer}</p>
        </div>
      )}
    </article>
  );
}

function ScoreBar({ label, value }: { label: string; value: number }) {
  const pct = Math.round(Math.max(0, Math.min(100, value)));
  const color = pct >= 75 ? "bg-ai" : pct >= 50 ? "bg-primary" : "bg-destructive";
  return (
    <div className="flex flex-col gap-1">
      <div className="flex items-center justify-between text-xs">
        <span className="text-muted-foreground">{label}</span>
        <span className="font-medium tabular-nums">{pct}</span>
      </div>
      <div className="progress-track h-2">
        {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width requires inline style */}
        <div className={`progress-fill h-full ${color}`} style={{ width: `${pct}%` }} aria-hidden />
      </div>
    </div>
  );
}

function FeedbackList({
  icon,
  label,
  items,
}: {
  icon: React.ReactNode;
  label: string;
  items: string[];
}) {
  return (
    <div className="flex flex-col gap-1">
      <p className="text-xs font-semibold text-muted-foreground">{label}</p>
      <ul className="flex flex-col gap-1">
        {items.map((item, i) => (
          <li key={i} className="flex items-start gap-2 text-sm">
            <span className="mt-0.5 shrink-0">{icon}</span>
            {item}
          </li>
        ))}
      </ul>
    </div>
  );
}
