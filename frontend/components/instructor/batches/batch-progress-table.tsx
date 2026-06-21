import { Users } from "lucide-react";
import { cn } from "@/lib/utils";
import type { MemberProgress } from "@/lib/server/batches";

interface BatchProgressTableProps {
  progress: MemberProgress[];
}

function scoreBadgeClass(avg: number | null | undefined): string {
  if (avg === null || avg === undefined) return "text-muted-foreground";
  if (avg >= 80) return "text-primary font-semibold";
  if (avg >= 60) return "text-foreground";
  return "text-destructive";
}

export function BatchProgressTable({ progress }: BatchProgressTableProps) {
  if (progress.length === 0) {
    return (
      <div className="empty-state py-10">
        <Users aria-hidden className="h-8 w-8 text-muted-foreground" />
        <p className="mt-2 text-sm text-muted-foreground">No students enrolled yet.</p>
      </div>
    );
  }

  return (
    <div className="table-responsive">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-border text-left text-xs text-muted-foreground">
            <th className="pb-2 font-medium">Student</th>
            <th className="pb-2 font-medium">Courses</th>
            <th className="pb-2 font-medium">Assessments</th>
            <th className="pb-2 font-medium">Avg score</th>
            <th className="pb-2 font-medium">Last active</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-border">
          {progress.map((s) => (
            <tr key={s.user_id}>
              <td className="py-2.5 pr-4">
                <div className="flex flex-col">
                  <span className="font-medium">{s.name}</span>
                  <span className="text-xs text-muted-foreground">{s.email}</span>
                </div>
              </td>
              <td className="py-2.5 pr-4">
                {s.completed_courses}/{s.enrolled_courses}
              </td>
              <td className="py-2.5 pr-4">{s.assessments_taken}</td>
              <td className={cn("py-2.5 pr-4", scoreBadgeClass(s.avg_score))}>
                {s.avg_score !== null ? `${Math.round(s.avg_score)}%` : "—"}
              </td>
              <td className="py-2.5 text-muted-foreground">
                {s.last_active ? new Date(s.last_active).toLocaleDateString() : "—"}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
