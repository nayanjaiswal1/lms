import { Flame, CheckCircle } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { DEMO_LEARNER } from "@/app/demo/tour/mock-data";

export function LearnerView() {
  const { name, streak, hoursThisWeek, weeklyGoalHrs, skillsAcquired, path, currentModule, aiRecommendation, recentActivity } = DEMO_LEARNER;
  const firstName = name.split(" ")[0];

  return (
    <div className="page-container py-8">
      {/* Section 1 — Header */}
      <header className="mb-6 flex items-center justify-between">
        <h2>Welcome back, <strong>{firstName}</strong> 👋</h2>
        <span className="flex items-center gap-1.5 rounded-full bg-primary/10 px-3 py-1.5 text-sm font-medium text-primary">
          <Flame aria-hidden className="h-4 w-4" />
          {streak} day streak
        </span>
      </header>

      {/* Section 2 — Stats */}
      <section aria-label="Learning stats" className="mb-6 grid-stats">
        <div className="card-base p-4">
          <p className="text-2xl font-bold">{hoursThisWeek}<span className="text-base font-normal text-muted-foreground"> / {weeklyGoalHrs} hrs</span></p>
          <p className="mt-1 text-sm text-muted-foreground">Hours this week</p>
        </div>
        <div className="card-base p-4">
          <p className="text-2xl font-bold">{path.progressPct}<span className="text-base font-normal text-muted-foreground">%</span></p>
          <p className="mt-1 text-sm text-muted-foreground">Path progress</p>
        </div>
        <div className="card-base p-4">
          <p className="text-2xl font-bold">{skillsAcquired.length}</p>
          <p className="mt-1 text-sm text-muted-foreground">Skills learned</p>
        </div>
        <div className="card-base p-4">
          <p className="text-2xl font-bold">{streak}</p>
          <p className="mt-1 text-sm text-muted-foreground">Day streak</p>
        </div>
      </section>

      {/* Section 3 — Current learning path */}
      <section aria-label="Learning path" className="mb-6">
        <div className="card-raised p-6">
          <p className="mb-1 text-xs font-medium uppercase tracking-wider text-muted-foreground">Your Learning Path</p>
          <h3 className="mb-3 text-xl font-semibold">{path.title}</h3>
          <div className="progress-track mb-2">
            {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width needs inline style */}
            <div className="progress-fill" style={{ width: `${path.progressPct}%` }} />
          </div>
          <p className="mb-5 text-sm text-muted-foreground">
            {path.completedModules} of {path.totalModules} modules complete · ~{path.estimatedWeeks} weeks remaining
          </p>

          {/* Current module card */}
          <div className="rounded-lg border border-border bg-muted/40 p-4">
            <div className="mb-2 flex items-center gap-2">
              <span className="rounded-full bg-primary/10 px-2 py-0.5 text-xs font-medium text-primary">Now playing</span>
            </div>
            <p className="text-sm font-medium text-foreground">
              {currentModule.course} · Module {currentModule.moduleNumber}: {currentModule.title}
            </p>
            <div className="progress-track my-2" style={{ height: "6px" }}>
              {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width needs inline style */}
              <div className="progress-fill" style={{ width: `${currentModule.progressPct}%` }} />
            </div>
            <p className="mb-3 text-xs text-muted-foreground">~{currentModule.minutesLeft} min remaining</p>
            <Button className="w-full" variant="outline">Continue learning →</Button>
          </div>
        </div>
      </section>

      {/* Section 4 — AI Recommendation */}
      <section aria-label="AI recommendation" className="mb-6">
        <div className="ai-surface p-5">
          <div className="mb-3 flex items-center gap-2">
            <span className="ai-badge">AI</span>
            <span className="text-sm font-medium text-foreground">Personalized recommendation</span>
          </div>
          <p className="mb-2 text-sm text-foreground">{aiRecommendation}</p>
          <p className="text-xs text-muted-foreground">
            You&apos;re on track to complete Full-Stack Dev in {path.estimatedWeeks} weeks. TypeScript Mastery is the recommended next path.
          </p>
        </div>
      </section>

      {/* Section 5 — Skills acquired */}
      <section aria-label="Skills acquired" className="mb-6">
        <p className="mb-3 text-sm font-medium text-muted-foreground">Skills you&apos;ve earned</p>
        <div className="flex flex-wrap gap-2">
          {skillsAcquired.map((skill) => (
            <Badge key={skill} variant="outline" className="badge-success">
              {skill}
            </Badge>
          ))}
        </div>
      </section>

      {/* Section 6 — Recent activity */}
      <section aria-label="Recent activity" className="mb-6">
        <p className="mb-3 text-sm font-medium text-muted-foreground">Recent activity</p>
        <div className="flex flex-col gap-2">
          {recentActivity.map((item) => (
            <div key={item.title} className="flex items-center gap-3 rounded-lg border border-border bg-card px-4 py-3">
              <CheckCircle aria-hidden className="h-4 w-4 shrink-0 text-success" />
              <span className="flex-1 text-sm text-foreground">{item.title}</span>
              <span className="text-xs text-muted-foreground">Completed {item.completedAt}</span>
            </div>
          ))}
        </div>
      </section>

      <p className="mt-8 text-center text-xs text-muted-foreground">
        Switch to Admin view to see how your manager tracks your progress ↑
      </p>
    </div>
  );
}
