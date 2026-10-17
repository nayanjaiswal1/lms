import Link from "next/link";
import { ClipboardCheck } from "lucide-react";

import ROUTES from "@/lib/routes";
import { getGradingQueue } from "@/lib/assessments/server";
import { DashboardEmptyState } from "./empty-state";
import { StatTiles } from "./stat-tiles";

const QUEUE_LIMIT = 10;

// "Awaiting review" widget shared by the teach and mentor dashboards.
// Caller gates on assessments.view_results.
export async function GradingQueue() {
  const queue = await getGradingQueue(QUEUE_LIMIT).catch(() => null);
  if (!queue) return null;
  return (
    <div className="flex flex-col gap-4">
      <StatTiles tiles={[{ label: "Awaiting review", value: queue.total }]} />
      {queue.items.length === 0 ? (
        <DashboardEmptyState icon={ClipboardCheck} message="Nothing waiting for grading." />
      ) : (
        <ul className="flex flex-col gap-3">
          {queue.items.map((i) => (
            <li key={i.attempt_id}>
              <Link
                className="card-base card-interactive flex min-w-0 flex-col gap-1 p-6 sm:flex-row sm:items-center sm:justify-between sm:gap-4"
                href={ROUTES.assessmentResults(i.assessment_id)}
              >
                <span className="min-w-0 truncate font-medium">{i.assessment_title}</span>
                <span className="text-sm text-muted-foreground">
                  {i.user_name ?? "Anonymous"}
                  {i.submitted_at ? ` · ${new Date(i.submitted_at).toLocaleDateString()}` : ""} · {i.ungraded_answers} ungraded
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
