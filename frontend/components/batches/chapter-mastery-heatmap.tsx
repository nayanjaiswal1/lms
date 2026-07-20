import type { ChapterMasteryCell, MasteryStatus } from "@/lib/server/batches";
import type { Terminology } from "@/lib/terminology";

interface ChapterMasteryHeatmapProps {
  cells: ChapterMasteryCell[];
  t: Terminology;
}

const STATUS_STYLE: Record<MasteryStatus, { className: string; label: string }> = {
  mastered:           { className: "bg-success",            label: "Mastered" },
  needs_practice:      { className: "bg-warning",            label: "Needs practice" },
  needs_review:        { className: "bg-destructive",        label: "Needs review" },
  insufficient_data:   { className: "bg-muted",              label: "Not started" },
};

export function ChapterMasteryHeatmap({ cells, t }: ChapterMasteryHeatmapProps) {
  if (cells.length === 0) {
    return (
      <div className="empty-state py-10">
        <p className="text-sm text-muted-foreground">No chapters assigned to this batch yet.</p>
      </div>
    );
  }

  const sections = new Map<string, string>();
  const students = new Map<string, { user_id: string; user_name: string; cells: Map<string, ChapterMasteryCell> }>();
  for (const cell of cells) {
    sections.set(cell.section_id, cell.section_title);
    let student = students.get(cell.user_id);
    if (!student) {
      student = { user_id: cell.user_id, user_name: cell.user_name, cells: new Map() };
      students.set(cell.user_id, student);
    }
    student.cells.set(cell.section_id, cell);
  }
  const sectionList = [...sections.entries()];
  const studentList = [...students.values()];

  return (
    <div className="flex flex-col gap-3">
      <div className="table-responsive">
        <table className="text-sm">
          <thead>
            <tr>
              <th className="sticky left-0 bg-background pb-2 pr-4 text-left text-xs font-medium text-muted-foreground">
                {t.student}
              </th>
              {sectionList.map(([id, title]) => (
                <th className="pb-2 px-1 text-center text-xs font-medium text-muted-foreground" key={id}>
                  <span className="block max-w-20 truncate" title={title}>{title}</span>
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {studentList.map((s) => (
              <tr key={s.user_id}>
                <td className="sticky left-0 bg-background py-1.5 pr-4 font-medium whitespace-nowrap">
                  {s.user_name}
                </td>
                {sectionList.map(([id]) => {
                  const cell = s.cells.get(id);
                  const style = STATUS_STYLE[cell?.status ?? "insufficient_data"];
                  const hintLabel = cell?.avg_hints !== null && cell?.avg_hints !== undefined
                    ? `${cell.avg_hints.toFixed(1)} avg hints`
                    : "no data";
                  return (
                    <td className="py-1.5 px-1 text-center" key={id}>
                      <span
                        aria-label={`${style.label} — ${hintLabel}`}
                        className={`inline-block h-4 w-4 rounded-sm ${style.className}`}
                        title={`${style.label} (${hintLabel})`}
                      />
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="flex flex-wrap items-center gap-4 text-xs text-muted-foreground">
        {(Object.entries(STATUS_STYLE) as [MasteryStatus, typeof STATUS_STYLE[MasteryStatus]][]).map(([status, style]) => (
          <div className="flex items-center gap-1.5" key={status}>
            <span aria-hidden className={`inline-block h-3 w-3 rounded-sm ${style.className}`} />
            {style.label}
          </div>
        ))}
      </div>
    </div>
  );
}
