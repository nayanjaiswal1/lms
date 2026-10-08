import { LoadMoreButton } from "@/components/shared/load-more-button";
import { UserLink } from "@/components/shared/user-link";
import { Badge } from "@/components/ui/badge";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import {
  ANALYTICS_MAX_LIMIT,
  ANALYTICS_PAGE_STEP,
  ANALYTICS_STUDENTS_DEFAULT_LIMIT,
  RISK_REASON_LABEL,
} from "@/lib/constants";
import type { CourseStudents } from "@/lib/server/course-analytics";

export function AtRiskStudentsTable({ data }: { data: CourseStudents }) {
  if (data.students.length === 0) {
    return (
      <div className="empty-state py-10">
        <p className="text-sm text-muted-foreground">No at-risk students match these filters.</p>
      </div>
    );
  }
  return (
    <>
      <ResponsiveTable>
        <table className="w-full text-sm">
          <thead>
            <tr className="whitespace-nowrap border-b border-border text-left text-xs text-muted-foreground">
              <th className="pb-2 font-medium">Student</th>
              <th className="pb-2 font-medium">Progress</th>
              <th className="pb-2 font-medium">Last active</th>
              <th className="pb-2 font-medium">Risk</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {data.students.map((s) => (
              <tr className="whitespace-nowrap" key={s.user_id}>
                <td className="max-w-xs py-3 pr-4">
                  <div className="flex min-w-0 flex-col">
                    <UserLink className="truncate font-medium hover:underline" userId={s.user_id}>{s.name}</UserLink>
                    <span className="truncate text-xs text-muted-foreground">{s.email}</span>
                  </div>
                </td>
                <td className="py-3 pr-4">
                  <div className="flex items-center gap-2">
                    <div className="progress-track w-24">
                      <div className="progress-fill" style={{ "--progress": `${s.progress_pct}%` } as React.CSSProperties} />
                    </div>
                    <span className="text-xs text-muted-foreground">{s.completed_modules}/{s.total_modules}</span>
                  </div>
                </td>
                <td className="py-3 pr-4 text-muted-foreground">
                  {s.last_active_at ? `${new Date(s.last_active_at).toLocaleDateString()} (${s.days_inactive ?? 0}d ago)` : "Never"}
                </td>
                <td className="py-3">
                  <div className="flex flex-wrap gap-1">
                    {s.risk_reasons.map((r) => (
                      <Badge key={r} variant="secondary">{RISK_REASON_LABEL[r] ?? r}</Badge>
                    ))}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </ResponsiveTable>
      <LoadMoreButton
        defaultLimit={ANALYTICS_STUDENTS_DEFAULT_LIMIT}
        hasMore={data.students.length < data.total}
        max={ANALYTICS_MAX_LIMIT}
        param="s_limit"
        step={ANALYTICS_PAGE_STEP}
      />
    </>
  );
}
