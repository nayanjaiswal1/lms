import { ResponsiveTable } from "@/components/ui/responsive-table";
import type { LessonStat } from "@/lib/server/course-analytics";

export function LessonDropoffTable({ lessons }: { lessons: LessonStat[] }) {
  if (lessons.length === 0) {
    return (
      <div className="empty-state py-10">
        <p className="text-sm text-muted-foreground">This course has no lessons yet.</p>
      </div>
    );
  }
  return (
    <ResponsiveTable>
      <table className="w-full text-sm">
        <thead>
          <tr className="whitespace-nowrap border-b border-border text-left text-xs text-muted-foreground">
            <th className="pb-2 font-medium">Lesson</th>
            <th className="pb-2 font-medium">Started</th>
            <th className="pb-2 font-medium">Completed</th>
            <th className="pb-2 font-medium">Completion</th>
            <th className="pb-2 font-medium">Drop-off</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-border">
          {lessons.map((l) => (
            <tr className="whitespace-nowrap" key={l.module_id}>
              <td className="max-w-xs py-3 pr-4">
                <p className="truncate font-medium">{l.title}</p>
                <p className="truncate text-xs text-muted-foreground">{l.section_title}</p>
              </td>
              <td className="py-3 pr-4">{l.started}</td>
              <td className="py-3 pr-4">{l.completed}</td>
              <td className="py-3 pr-4">{Math.round(l.completion_rate * 100)}%</td>
              <td className="py-3 text-muted-foreground">{l.drop_off}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </ResponsiveTable>
  );
}
