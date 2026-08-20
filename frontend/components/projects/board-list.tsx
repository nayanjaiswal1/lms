import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { APPLICATION_STATUS_LABEL, APPLICATION_STATUS_VARIANT } from "@/lib/constants";
import type { RequirementBoardRow } from "@/lib/projects/types";
import ROUTES from "@/lib/routes";

interface BoardListProps {
  rows: RequirementBoardRow[];
}

function daysUntil(iso: string): number {
  return Math.ceil((new Date(iso).getTime() - Date.now()) / 86_400_000);
}

export function BoardList({ rows }: BoardListProps) {
  return (
    <div className="card-grid">
      {rows.map((row) => {
        const daysLeft = daysUntil(row.application_deadline);
        return (
          <Link
            className="card-base card-interactive flex flex-col gap-3 p-6"
            href={ROUTES.boardRequirement(row.id)}
            key={row.id}
          >
            <div className="flex items-start justify-between gap-2">
              <span className="text-base font-semibold">{row.title}</span>
              {row.my_status ? (
                <Badge variant={APPLICATION_STATUS_VARIANT[row.my_status] ?? "outline"}>
                  {APPLICATION_STATUS_LABEL[row.my_status] ?? row.my_status}
                </Badge>
              ) : (
                daysLeft <= 2 && (
                  <Badge variant="destructive">{daysLeft <= 0 ? "Closes today" : `${daysLeft}d left`}</Badge>
                )
              )}
            </div>
            <p className="line-clamp-2 text-sm text-muted-foreground">{row.brief}</p>
            <div className="flex flex-wrap gap-1.5">
              {row.required_skills.map((skill) => (
                <Badge key={skill} variant="outline">
                  {skill}
                </Badge>
              ))}
            </div>
            <span className="text-xs text-muted-foreground">
              Team of {row.team_size_min}–{row.team_size_max} · {row.application_count} applicant
              {row.application_count === 1 ? "" : "s"} · closes {new Date(row.application_deadline).toLocaleDateString()}
            </span>
          </Link>
        );
      })}
    </div>
  );
}
