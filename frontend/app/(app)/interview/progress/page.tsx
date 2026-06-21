import type { Metadata } from "next";
import { TrendingUp, TrendingDown, Minus, Target } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { getStudentProgress } from "@/lib/server/assessments";
import type { SkillTrend } from "@/lib/assessments/types";

export const metadata: Metadata = { title: "Interview Readiness" };

export default async function InterviewProgressPage() {
  const progress = await getStudentProgress();

  const readiness = progress.latest_readiness_score;
  const avg = Math.round(progress.avg_readiness_score);

  return (
    <main className="page-container py-10">
      <div className="page-header">
        <h1 className="page-title">Interview Readiness</h1>
      </div>

      <div className="grid-stats mb-8">
        <StatCard label="Total evaluated" value={String(progress.total_evaluated)} />
        <StatCard
          label="Latest readiness"
          value={readiness !== null ? `${Math.round(readiness)}%` : "—"}
        />
        <StatCard label="Average readiness" value={`${avg}%`} />
        <StatCard label="Skills tracked" value={String(progress.skill_trends.length)} />
      </div>

      {progress.skill_trends.length > 0 ? (
        <section>
          <h2 className="section-title mb-4">Skill breakdown</h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {progress.skill_trends.map((skill) => (
              <SkillCard key={skill.skill} skill={skill} />
            ))}
          </div>
        </section>
      ) : (
        <div className="empty-state">
          <Target aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="text-muted-foreground">
            Complete a mock interview assessment to see your skill trends here.
          </p>
        </div>
      )}
    </main>
  );
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="card-base flex flex-col gap-1 p-5">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="text-2xl font-bold tabular-nums">{value}</p>
    </div>
  );
}

function SkillCard({ skill }: { skill: SkillTrend }) {
  const latest = Math.round(skill.latest_score);
  const avg = Math.round(skill.avg_score);
  const pct = Math.max(0, Math.min(100, latest));
  const barColor = skill.is_strong ? "bg-ai" : skill.is_weak ? "bg-destructive" : "bg-primary";

  return (
    <article className="card-base flex flex-col gap-3 p-5">
      <div className="flex items-center justify-between gap-2">
        <h3 className="font-medium capitalize">{skill.skill}</h3>
        {skill.is_strong ? (
          <Badge variant="default">Strong</Badge>
        ) : skill.is_weak ? (
          <Badge variant="destructive">Needs work</Badge>
        ) : null}
      </div>

      <div className="progress-track h-2">
        {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width requires inline style */}
        <div className={`progress-fill h-full ${barColor}`} style={{ width: `${pct}%` }} aria-hidden />
      </div>

      <div className="flex items-center justify-between text-xs text-muted-foreground">
        <span className="flex items-center gap-1">
          {latest > avg ? (
            <TrendingUp className="h-3 w-3 text-ai" aria-hidden />
          ) : latest < avg ? (
            <TrendingDown className="h-3 w-3 text-destructive" aria-hidden />
          ) : (
            <Minus className="h-3 w-3" aria-hidden />
          )}
          Latest: {latest}
        </span>
        <span>Avg: {avg} · {skill.attempt_count} attempt{skill.attempt_count !== 1 ? "s" : ""}</span>
      </div>
    </article>
  );
}
