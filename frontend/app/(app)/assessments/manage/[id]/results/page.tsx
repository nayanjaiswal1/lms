import type { Metadata } from "next";
import type { ReactNode } from "react";
import { notFound } from "next/navigation";
import { Users, Trophy, Clock, ShieldAlert, TrendingUp, TrendingDown } from "lucide-react";

import { AttemptsTable } from "@/components/assessments/attempts-table";
import { getAssessment, getAssessmentAnalytics, getAssessmentAttempts, getAssessmentCandidates } from "@/lib/server/assessments";
import type { PublicCandidate } from "@/lib/server/public";

export const metadata: Metadata = {
  title: "Assessment Results",
};

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function ResultsPage({ params }: PageProps) {
  const { id } = await params;

  let detail: Awaited<ReturnType<typeof getAssessment>>;
  try {
    detail = await getAssessment(id);
  } catch {
    notFound();
  }
  const isHiring = detail.assessment.parent_type === "hiring";
  const [analytics, attempts, candidates] = await Promise.all([
    getAssessmentAnalytics(id),
    getAssessmentAttempts(id),
    isHiring ? getAssessmentCandidates(id) : Promise.resolve<PublicCandidate[]>([]),
  ]);

  return (
    <main className="page-container py-10">
      <header className="mb-6 flex flex-col gap-1">
        <h1 className="page-title">{detail.assessment.title}</h1>
        <p className="text-muted-foreground">Results &amp; analytics</p>
      </header>

      <section className="grid-stats grid gap-4">
        <Stat
          icon={<Users className="h-5 w-5 text-primary" />}
          label="Total attempts"
          sub={`${analytics.evaluated} evaluated`}
          value={String(analytics.total_attempts)}
        />
        <Stat
          icon={<Trophy className="h-5 w-5 text-primary" />}
          label="Pass rate"
          sub={`avg ${Math.round(analytics.avg_percentage)}%`}
          value={`${Math.round(analytics.pass_rate)}%`}
        />
        <Stat
          icon={<Clock className="h-5 w-5 text-primary" />}
          label="Avg time"
          sub={`high ${Math.round(analytics.high_score)}% · low ${Math.round(analytics.low_score)}%`}
          value={`${Math.round(analytics.avg_duration_sec / 60)}m`}
        />
        <Stat
          icon={<ShieldAlert className="h-5 w-5 text-destructive" />}
          label="Flagged"
          sub={
            analytics.total_attempts > 0
              ? `${Math.round((analytics.flagged_attempts / analytics.total_attempts) * 100)}% of attempts`
              : "—"
          }
          value={String(analytics.flagged_attempts)}
        />
      </section>

      {analytics.score_buckets && Object.keys(analytics.score_buckets).length > 0 && (
        <section className="mt-10">
          <h2 className="section-title mb-4">Score distribution</h2>
          <ScoreDistribution buckets={analytics.score_buckets} total={analytics.total_attempts} />
        </section>
      )}

      {analytics.question_stats.length > 0 && (
        <section className="mt-10">
          <h2 className="section-title mb-3">Question difficulty (correct rate)</h2>
          <div className="flex flex-col gap-2">
            {analytics.question_stats
              .slice()
              .sort((a, b) => a.correct_rate - b.correct_rate)
              .map((q) => (
                <div className="card-base flex items-center gap-4 p-4" key={q.question_id}>
                  <span className="flex-1 truncate text-sm font-medium">{q.title}</span>
                  {q.correct_rate < 40 ? (
                    <TrendingDown className="h-4 w-4 shrink-0 text-destructive" />
                  ) : (
                    <TrendingUp className="h-4 w-4 shrink-0 text-primary" />
                  )}
                  <div className="progress-track w-40">
                    {/* eslint-disable-next-line no-restricted-syntax -- dynamic correctness width must be an inline CSS var */}
                    <div
                      className="progress-fill"
                      style={{ width: `${Math.round(q.correct_rate)}%` }}
                    />
                  </div>
                  <span className="w-12 text-right text-sm tabular-nums">
                    {Math.round(q.correct_rate)}%
                  </span>
                </div>
              ))}
          </div>
        </section>
      )}

      {isHiring && (
        <section className="mt-10">
          <h2 className="section-title mb-4">Candidates</h2>
          <CandidatesTable candidates={candidates} />
        </section>
      )}

      {!isHiring && (
        <section className="mt-10">
          <h2 className="section-title mb-4">Attempts</h2>
          {attempts.length === 0 ? (
            <p className="text-sm text-muted-foreground">No attempts yet.</p>
          ) : (
            <AttemptsTable attempts={attempts} />
          )}
        </section>
      )}
    </main>
  );
}

function Stat({
  icon,
  label,
  value,
  sub,
}: {
  icon: ReactNode;
  label: string;
  value: string;
  sub?: string;
}) {
  return (
    <div className="card-base flex items-center gap-3 p-4">
      <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-muted">
        {icon}
      </span>
      <div className="min-w-0">
        <p className="text-xs text-muted-foreground">{label}</p>
        <p className="text-lg font-semibold tabular-nums">{value}</p>
        {sub && <p className="truncate text-xs text-muted-foreground">{sub}</p>}
      </div>
    </div>
  );
}

const BUCKET_ORDER = ["0-20", "21-40", "41-60", "61-80", "81-100"] as const;
const BUCKET_LABELS: Record<string, string> = {
  "0-20": "0–20%",
  "21-40": "21–40%",
  "41-60": "41–60%",
  "61-80": "61–80%",
  "81-100": "81–100%",
};

function ScoreDistribution({
  buckets,
  total,
}: {
  buckets: Record<string, number>;
  total: number;
}) {
  const max = Math.max(1, ...BUCKET_ORDER.map((k) => buckets[k] ?? 0));

  return (
    <div className="card-base p-4">
      <div className="flex h-36 items-end gap-2">
        {BUCKET_ORDER.map((key) => {
          const count = buckets[key] ?? 0;
          const pct = total > 0 ? Math.round((count / total) * 100) : 0;
          const barPct = Math.round((count / max) * 100);
          return (
            <div className="flex flex-1 flex-col items-center gap-1" key={key}>
              <span className="text-xs tabular-nums text-muted-foreground">{pct}%</span>
              <div className="flex w-full items-end" style={{ height: "80px" }}>
                {/* eslint-disable-next-line no-restricted-syntax -- dynamic bar height requires inline style */}
                <div
                  className={`w-full rounded-t-sm ${key === "81-100" ? "bg-primary" : "bg-muted-foreground/40"}`}
                  style={{ height: `${barPct}%` }}
                />
              </div>
              <span className="text-xs text-muted-foreground">{BUCKET_LABELS[key] ?? key}</span>
              <span className="text-xs font-medium tabular-nums">{count}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function CandidatesTable({ candidates }: { candidates: PublicCandidate[] }) {
  if (candidates.length === 0) {
    return <p className="text-sm text-muted-foreground">No candidates yet. Share the public link to start receiving applications.</p>;
  }

  const fmt = (sec: number | undefined) => {
    if (!sec) return "—";
    const m = Math.floor(sec / 60);
    const s = sec % 60;
    return `${m}m ${s}s`;
  };

  return (
    <div className="table-responsive">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-border text-left text-muted-foreground">
            <th className="py-3 pr-4 font-medium">Candidate</th>
            <th className="py-3 pr-4 font-medium">Email</th>
            <th className="py-3 pr-4 font-medium">Status</th>
            <th className="py-3 pr-4 font-medium">Score</th>
            <th className="py-3 pr-4 font-medium">Result</th>
            <th className="py-3 pr-4 font-medium">Duration</th>
          </tr>
        </thead>
        <tbody>
          {candidates.map((c) => (
            <tr className="border-b border-border/60" key={c.id}>
              <td className="py-3 pr-4 font-medium">{c.name}</td>
              <td className="py-3 pr-4 text-muted-foreground">{c.email}</td>
              <td className="py-3 pr-4 capitalize text-muted-foreground">{c.status}</td>
              <td className="py-3 pr-4 tabular-nums">
                {c.percentage != null ? `${Math.round(c.percentage)}%` : "—"}
              </td>
              <td className="py-3 pr-4">
                {c.passed == null ? (
                  <span className="text-muted-foreground">—</span>
                ) : c.passed ? (
                  <span className="font-medium text-primary">Passed</span>
                ) : (
                  <span className="text-destructive">Failed</span>
                )}
              </td>
              <td className="py-3 pr-4 tabular-nums text-muted-foreground">
                {fmt(c.duration_sec)}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
