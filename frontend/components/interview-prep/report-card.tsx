import Link from "next/link";
import { BookOpen } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { PracticeAgainButton } from "@/components/interview-prep/practice-again-button";
import { IconMessage } from "@/components/shared/icon-message";
import type { PrepReport } from "@/lib/server/interview-prep";
import ROUTES from "@/lib/routes";

interface ReportCardProps {
  jobTitle: string;
  report: PrepReport;
}

export function ReportCard({ jobTitle, report }: ReportCardProps) {
  return (
    <div className="flex flex-col gap-6">
      <div className="card-raised flex flex-col items-center gap-2 p-8 text-center">
        <span className="ai-badge">Readiness score</span>
        <span className="text-5xl font-bold text-primary">{Math.round(report.readiness_score)}</span>
        <span className="text-sm text-muted-foreground">out of 100</span>
      </div>

      <div className="grid-responsive-2 gap-4">
        <div className="card-base p-4">
          <p className="text-sm text-muted-foreground">Conceptual round</p>
          <p className="mt-1 text-2xl font-semibold">{Math.round(report.conceptual_score_pct)}%</p>
        </div>
        <div className="card-base p-4">
          <p className="text-sm text-muted-foreground">Coding round</p>
          <p className="mt-1 text-2xl font-semibold">{Math.round(report.coding_pass_rate_pct)}%</p>
        </div>
      </div>

      <div className="ai-surface flex flex-col gap-3 rounded-lg p-5">
        <div className="ai-badge w-fit">AI Summary</div>
        <p className="text-sm leading-relaxed">{report.summary}</p>
      </div>

      {report.strong_skills.length > 0 && (
        <section className="flex flex-col gap-2">
          <h3 className="text-sm font-semibold">Strong skills</h3>
          <div className="flex flex-wrap gap-1.5">
            {report.strong_skills.map((s) => (
              <Badge className="badge-success" key={s}>{s}</Badge>
            ))}
          </div>
        </section>
      )}

      {report.weak_skills.length > 0 && (
        <section className="flex flex-col gap-2">
          <h3 className="text-sm font-semibold">Areas to improve</h3>
          <div className="flex flex-wrap gap-1.5">
            {report.weak_skills.map((s) => (
              <Badge key={s} variant="outline">{s}</Badge>
            ))}
          </div>
        </section>
      )}

      {report.cards_added > 0 && (
        <IconMessage
          action={
            <Button asChild size="sm" variant="outline">
              <Link href={ROUTES.REVIEW}>Revise now</Link>
            </Button>
          }
          className="card-base gap-4 p-4"
          icon={BookOpen}
          size="md"
          tone="ai"
          variant="plain"
        >
          <p className="text-sm font-medium">
            {report.cards_added} revision card{report.cards_added === 1 ? "" : "s"} added
          </p>
          <p className="text-sm text-muted-foreground">
            Everything you missed is now in your spaced-repetition queue.
          </p>
        </IconMessage>
      )}

      {report.next_steps.length > 0 && (
        <section className="flex flex-col gap-2">
          <h3 className="text-sm font-semibold">Next steps</h3>
          <ul className="flex flex-col gap-1.5">
            {report.next_steps.map((step, i) => (
              <li className="text-sm text-muted-foreground" key={i}>{step}</li>
            ))}
          </ul>
        </section>
      )}

      <PracticeAgainButton jobTitle={jobTitle} weakSkills={report.weak_skills} />
    </div>
  );
}
