import { Users } from "lucide-react";
import type { MemberProgress } from "@/lib/server/batches";

interface BatchProgressTableProps {
  progress: MemberProgress[];
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
            <th className="pb-2 font-medium">Tests passed</th>
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
                {s.courses_completed}/{s.courses_enrolled}
              </td>
              <td className="py-2.5 pr-4">{s.tests_passed}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
