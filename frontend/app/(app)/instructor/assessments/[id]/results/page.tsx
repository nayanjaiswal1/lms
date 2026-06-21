import type { Metadata } from "next";
import type { ReactNode } from "react";
import { notFound } from "next/navigation";
import { Users, Trophy, Clock, ShieldAlert } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { getAssessment, getAssessmentAnalytics, getAssessmentAttempts } from "@/lib/server/assessments";

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
  const [analytics, attempts] = await Promise.all([getAssessmentAnalytics(id), getAssessmentAttempts(id)]);

  return (
    <main className="page-container py-10">
      <header className="mb-6 flex flex-col gap-1">
        <h1 className="page-title">{detail.assessment.title}</h1>
        <p className="text-muted-foreground">Results &amp; analytics</p>
      </header>

      <section className="grid-stats grid gap-4">
        <Stat icon={<Users className="h-5 w-5 text-primary" />} label="Attempts" value={String(analytics.total_attempts)} />
        <Stat icon={<Trophy className="h-5 w-5 text-primary" />} label="Pass rate" value={`${Math.round(analytics.pass_rate)}%`} />
        <Stat icon={<Clock className="h-5 w-5 text-primary" />} label="Avg time" value={`${Math.round(analytics.avg_duration_sec / 60)}m`} />
        <Stat icon={<ShieldAlert className="h-5 w-5 text-destructive" />} label="Flagged" value={String(analytics.flagged_attempts)} />
      </section>

      {analytics.question_stats.length > 0 && (
        <section className="mt-10">
          <h2 className="section-title mb-3">Question difficulty (correct rate)</h2>
          <div className="flex flex-col gap-2">
            {analytics.question_stats.map((q) => (
              <div className="card-base flex items-center gap-4 p-4" key={q.question_id}>
                <span className="flex-1 truncate text-sm font-medium">{q.title}</span>
                <div className="progress-track w-40">
                  {/* eslint-disable-next-line no-restricted-syntax -- dynamic correctness width must be an inline CSS var */}
                  <div className="progress-fill" style={{ width: `${Math.round(q.correct_rate)}%` }} />
                </div>
                <span className="w-12 text-right text-sm tabular-nums">{Math.round(q.correct_rate)}%</span>
              </div>
            ))}
          </div>
        </section>
      )}

      <section className="mt-10">
        <h2 className="section-title mb-3">Attempts</h2>
        {attempts.length === 0 ? (
          <p className="text-sm text-muted-foreground">No attempts yet.</p>
        ) : (
          <div className="table-responsive">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left text-muted-foreground">
                  <th className="py-3 pr-4 font-medium">Student</th>
                  <th className="py-3 pr-4 font-medium">Status</th>
                  <th className="py-3 pr-4 font-medium">Score</th>
                  <th className="py-3 pr-4 font-medium">Result</th>
                  <th className="py-3 pr-4 font-medium">Time</th>
                  <th className="py-3 pr-4 font-medium">Flags</th>
                </tr>
              </thead>
              <tbody>
                {attempts.map((a) => (
                  <tr className="border-b border-border/60" key={a.id}>
                    <td className="py-3 pr-4">
                      <p className="font-medium">{a.user_name}</p>
                      <p className="text-xs text-muted-foreground">{a.user_email}</p>
                    </td>
                    <td className="py-3 pr-4 capitalize text-muted-foreground">{a.status}</td>
                    <td className="py-3 pr-4 tabular-nums">{a.percentage !== null ? `${Math.round(a.percentage)}%` : "—"}</td>
                    <td className="py-3 pr-4">
                      {a.passed === null ? (
                        <span className="text-muted-foreground">—</span>
                      ) : (
                        <Badge variant={a.passed ? "default" : "destructive"}>{a.passed ? "Passed" : "Failed"}</Badge>
                      )}
                    </td>
                    <td className="py-3 pr-4 tabular-nums text-muted-foreground">{Math.round(a.duration_sec / 60)}m</td>
                    <td className="py-3 pr-4">
                      {a.flags > 0 ? <Badge variant="destructive">{a.flags}</Badge> : <span className="text-muted-foreground">0</span>}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </main>
  );
}

function Stat({ icon, label, value }: { icon: ReactNode; label: string; value: string }) {
  return (
    <div className="card-base flex items-center gap-3 p-4">
      <span className="flex h-10 w-10 items-center justify-center rounded-md bg-muted">{icon}</span>
      <div>
        <p className="text-xs text-muted-foreground">{label}</p>
        <p className="text-lg font-semibold tabular-nums">{value}</p>
      </div>
    </div>
  );
}
