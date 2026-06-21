import type { Metadata } from "next";
import Link from "next/link";
import { ClipboardCheck, Plus, BarChart3 } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { getAssessments, getOrgAnalytics } from "@/lib/server/assessments";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Assessments",
  description: "Author, publish, and assign assessments.",
};

const STATUS_VARIANT: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  draft: "outline",
  published: "default",
  scheduled: "secondary",
  active: "default",
  completed: "secondary",
  archived: "destructive",
};

export default async function InstructorAssessmentsPage() {
  const [assessments, org] = await Promise.all([getAssessments(), getOrgAnalytics()]);

  return (
    <main className="page-container py-10">
      <header className="page-header">
        <div className="flex flex-col gap-1">
          <h1 className="page-title">Assessments</h1>
          <p className="text-muted-foreground">
            {org.total_assessments} assessments · {org.total_attempts} attempts · {Math.round(org.avg_pass_rate)}% avg pass rate
          </p>
        </div>
        <Button asChild>
          <Link href={ROUTES.ADMIN_ASSESSMENT_NEW}>
            <Plus /> New assessment
          </Link>
        </Button>
      </header>

      {assessments.length === 0 ? (
        <div className="empty-state mt-10">
          <ClipboardCheck aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="mt-3 font-medium">No assessments yet</p>
          <p className="text-sm text-muted-foreground">Create one, add questions from your bank, then assign it.</p>
        </div>
      ) : (
        <section className="card-grid mt-8">
          {assessments.map((a) => (
            <article className="card-interactive flex flex-col gap-3 p-6" key={a.id}>
              <div className="flex items-start justify-between gap-2">
                <Link className="text-base font-semibold hover:underline" href={ROUTES.adminAssessment(a.id)}>
                  {a.title}
                </Link>
                <Badge variant={STATUS_VARIANT[a.status] ?? "outline"}>{a.status}</Badge>
              </div>
              <div className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
                <span>{a.type}</span>
                <span>{a.question_count} questions</span>
                <span>{a.duration_minutes} min</span>
                <span>{a.total_points} pts</span>
              </div>
              <div className="mt-auto flex gap-2">
                <Button asChild size="sm" variant="outline">
                  <Link href={ROUTES.adminAssessment(a.id)}>Edit</Link>
                </Button>
                <Button asChild size="sm" variant="ghost">
                  <Link href={ROUTES.adminAssessmentResults(a.id)}>
                    <BarChart3 /> Results
                  </Link>
                </Button>
              </div>
            </article>
          ))}
        </section>
      )}
    </main>
  );
}
