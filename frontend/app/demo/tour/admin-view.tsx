import { cn } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";
import { DEMO_ORG, DEMO_TEAM, DEMO_COMPLIANCE, type MemberStatus } from "@/app/demo/tour/mock-data";

function statusLabel(status: MemberStatus): string {
  switch (status) {
    case "completed":    return "Completed";
    case "in_progress":  return "In progress";
    case "overdue":      return "Overdue";
    case "not_started":  return "Not started";
  }
}

function statusClass(status: MemberStatus): string {
  switch (status) {
    case "completed":    return "badge-success";
    case "in_progress":  return "badge-muted";
    case "overdue":      return "badge-destructive";
    case "not_started":  return "badge-muted";
  }
}

export function AdminView() {
  const { name, totalMembers, activeMembers, avgCompletionPct, overdueCount, assignedPaths } = DEMO_ORG;

  return (
    <div className="page-container py-8">
      {/* Section 1 — Header */}
      <header className="mb-6 flex items-center justify-between">
        <h2>{name} · Team Overview</h2>
        <span className="rounded-full border border-border px-3 py-1 text-xs text-muted-foreground">
          {totalMembers} members
        </span>
      </header>

      {/* Section 2 — Stats */}
      <section aria-label="Team stats" className="mb-6 grid-stats">
        <div className="card-base p-4">
          <p className="text-2xl font-bold">{activeMembers}<span className="text-base font-normal text-muted-foreground"> / {totalMembers}</span></p>
          <p className="mt-1 text-sm text-muted-foreground">Active learners</p>
        </div>
        <div className="card-base p-4">
          <p className="text-2xl font-bold">{avgCompletionPct}<span className="text-base font-normal text-muted-foreground">%</span></p>
          <p className="mt-1 text-sm text-muted-foreground">Avg completion</p>
        </div>
        <div className="card-base p-4">
          <p className="text-2xl font-bold text-destructive">{overdueCount}</p>
          <p className="mt-1 text-sm text-muted-foreground">Overdue</p>
        </div>
        <div className="card-base p-4">
          <p className="text-2xl font-bold">{assignedPaths}</p>
          <p className="mt-1 text-sm text-muted-foreground">Paths assigned</p>
        </div>
      </section>

      {/* Section 3 — Compliance */}
      <section aria-label="Compliance training" className="mb-6">
        <div className="rounded-xl border border-primary/30 bg-primary/5 p-5">
          <p className="mb-4 text-sm font-semibold text-foreground">Compliance Training</p>
          <div className="flex flex-col gap-4">
            {DEMO_COMPLIANCE.map((item) => {
              const pct = Math.round((item.completedCount / item.totalCount) * 100);
              return (
                <div key={item.title}>
                  <div className="mb-1.5 flex flex-wrap items-center justify-between gap-1">
                    <span className="text-sm font-medium text-foreground">
                      ⚠ {item.title}
                    </span>
                    <span className="text-xs text-muted-foreground">Due in {item.dueInDays} days</span>
                  </div>
                  <div className="progress-track mb-1">
                    {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width needs inline style */}
                    <div className="progress-fill" style={{ width: `${pct}%` }} />
                  </div>
                  <p className="text-xs text-muted-foreground">
                    {item.completedCount} of {item.totalCount} completed ({pct}%)
                  </p>
                </div>
              );
            })}
          </div>
        </div>
      </section>

      {/* Section 4 — Team roster */}
      <section aria-label="Team roster" className="mb-6">
        <p className="mb-3 text-sm font-medium text-muted-foreground">Team members</p>
        <div className="table-responsive">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Role</th>
                <th>Course</th>
                <th>Progress</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {DEMO_TEAM.map((member) => (
                <tr key={member.name}>
                  <td>
                    <span className="font-medium text-foreground">{member.name}</span>
                    {member.isYou && (
                      <span className="ml-2 text-xs font-medium text-primary">← you</span>
                    )}
                  </td>
                  <td>
                    <span className="text-sm text-muted-foreground">{member.role}</span>
                  </td>
                  <td>
                    <span className="text-sm text-foreground">{member.course}</span>
                  </td>
                  <td>
                    <div className="flex items-center gap-2">
                      <div className="h-1.5 w-24 overflow-hidden rounded-full bg-muted">
                        {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width needs inline style */}
                        <div
                          className="h-full rounded-full bg-primary"
                          style={{ width: `${member.progressPct}%` }}
                        />
                      </div>
                      <span className="text-xs text-muted-foreground">{member.progressPct}%</span>
                    </div>
                  </td>
                  <td>
                    <Badge
                      variant="outline"
                      className={cn(statusClass(member.status))}
                    >
                      {statusLabel(member.status)}
                    </Badge>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <p className="mt-8 text-center text-xs text-muted-foreground">
        Switch to Learner view to see the platform from Alex&apos;s perspective ↑
      </p>
    </div>
  );
}
