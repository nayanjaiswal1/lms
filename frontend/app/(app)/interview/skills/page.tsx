import type { Metadata } from "next";
import { TrendingUp, TrendingDown, Minus, BarChart2 } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { getSkillTrends } from "@/lib/server/assessments";
import type { SkillTrend } from "@/lib/assessments/types";

export const metadata: Metadata = { title: "Skill Trends" };

export default async function InterviewSkillsPage() {
  const { skill_trends } = await getSkillTrends();

  const strong = skill_trends.filter((s) => s.is_strong).length;
  const weak = skill_trends.filter((s) => s.is_weak).length;
  const avgScore =
    skill_trends.length > 0
      ? Math.round(skill_trends.reduce((sum, s) => sum + s.avg_score, 0) / skill_trends.length)
      : 0;

  return (
    <main className="page-container py-10">
      <div className="page-header">
        <h1 className="page-title">Skill Trends</h1>
      </div>

      <div className="grid-stats mb-8">
        <StatCard label="Skills tracked" value={String(skill_trends.length)} />
        <StatCard label="Strong skills" value={String(strong)} />
        <StatCard label="Needs work" value={String(weak)} />
        <StatCard label="Average score" value={skill_trends.length > 0 ? `${avgScore}%` : "—"} />
      </div>

      {skill_trends.length > 0 ? (
        <section>
          <h2 className="section-title mb-4">Skill breakdown</h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {skill_trends.map((skill) => (
              <SkillCard key={skill.skill} skill={skill} />
            ))}
          </div>
        </section>
      ) : (
        <div className="empty-state">
          <BarChart2 aria-hidden className="h-10 w-10 text-muted-foreground" />
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
        <span>
          Avg: {avg} · {skill.attempt_count} attempt{skill.attempt_count !== 1 ? "s" : ""}
        </span>
      </div>
    </article>
  );
}
