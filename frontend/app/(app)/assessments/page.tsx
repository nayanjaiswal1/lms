import type { Metadata } from "next";
import type { ReactNode } from "react";
import Link from "next/link";
import { ClipboardCheck, Clock, Loader2, Target, Trophy } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { getMyAssessments, getMyAnalytics } from "@/lib/server/assessments";
import ROUTES from "@/lib/routes";
import type { AssignedAssessment } from "@/lib/assessments/types";

export const metadata: Metadata = {
  title: "Assessments",
  description: "Your assigned tests and results.",
};

function cta(a: AssignedAssessment) {
  if (a.active_attempt_id) {
    return { label: "Resume", href: ROUTES.assessmentTake(a.id), variant: "default" as const };
  }
  if (a.evaluating_attempt_id) {
    return { label: "View progress", href: ROUTES.assessmentResult(a.evaluating_attempt_id), variant: "outline" as const };
  }
  if (a.attempts_used < a.max_attempts) {
    const label = a.attempts_used === 0 ? "Start" : "Retake";
    return { label, href: ROUTES.assessmentTake(a.id), variant: "default" as const };
  }
  return null;
}

export default async function AssessmentsPage() {
  const [assessments, analytics] = await Promise.all([getMyAssessments(), getMyAnalytics()]);

  return (
    <main className="page-container py-10">
      <header className="page-header">
        <div className="flex flex-col gap-1">
          <h1 className="page-title">Assessments</h1>
          <p className="text-muted-foreground">Tests assigned to you across your courses and batches.</p>
        </div>
      </header>

      <section className="grid-stats mt-4 grid gap-4">
        <Stat icon={<ClipboardCheck className="h-5 w-5 text-primary" />} label="Completed" value={String(analytics.completed)} />
        <Stat icon={<Trophy className="h-5 w-5 text-primary" />} label="Passed" value={String(analytics.passed)} />
        <Stat icon={<Target className="h-5 w-5 text-primary" />} label="Avg score" value={`${Math.round(analytics.avg_percentage)}%`} />
        <Stat icon={<Clock className="h-5 w-5 text-primary" />} label="Time spent" value={`${Math.round(analytics.total_time_sec / 60)}m`} />
      </section>

      {assessments.length === 0 ? (
        <div className="empty-state mt-10">
          <ClipboardCheck aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="mt-3 font-medium">No assessments assigned yet</p>
          <p className="text-sm text-muted-foreground">Assigned tests will appear here when your mentor schedules them.</p>
        </div>
      ) : (
        <section className="card-grid mt-8">
          {assessments.map((a) => {
            const action = cta(a);
            return (
              <article className="card-base flex flex-col gap-4 p-6" key={a.id}>
                <div className="flex items-start justify-between gap-2">
                  <h3 className="text-base font-semibold">{a.title}</h3>
                  <Badge variant="secondary">{a.type}</Badge>
                </div>
                {a.description && <p className="line-clamp-2 text-sm text-muted-foreground">{a.description}</p>}

                <div className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
                  <span>{a.duration_minutes} min</span>
                  <span>{a.question_count} questions</span>
                  <span>Pass {a.pass_percentage}%</span>
                  <span>
                    Attempt {a.attempts_used}/
                    {a.max_attempts >= 100 ? "∞" : a.max_attempts}
                  </span>
                </div>

                {a.evaluating_attempt_id && (
                  <div className="ai-surface flex items-center gap-2 rounded-[--radius-md] px-3 py-2">
                    <Loader2 aria-hidden className="h-3.5 w-3.5 animate-spin text-ai" />
                    <span className="text-sm font-medium text-ai">AI is reviewing your answers…</span>
                  </div>
                )}

                {a.best_percentage !== null && !a.evaluating_attempt_id && (
                  <p className="text-sm">
                    Best:{" "}
                    <span className={a.best_passed ? "font-semibold text-ai" : "font-semibold text-destructive"}>
                      {Math.round(a.best_percentage)}% {a.best_passed ? "· Passed" : "· Not passed"}
                    </span>
                  </p>
                )}

                <div className="mt-auto">
                  {action ? (
                    <Button asChild className="w-full" variant={action.variant}>
                      <Link href={action.href}>{action.label}</Link>
                    </Button>
                  ) : (
                    <Button disabled className="w-full" variant="outline">
                      No attempts left
                    </Button>
                  )}
                </div>
              </article>
            );
          })}
        </section>
      )}
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
