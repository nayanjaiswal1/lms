import { Suspense } from "react";
import Link from "next/link";
import { Briefcase, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { listPrepPlans } from "@/lib/server/interview-prep";
import ROUTES from "@/lib/routes";

export const metadata = { title: "Interview Prep — MindForge" };

const STATUS_BADGE: Record<string, string> = {
  generating:  "border border-border text-muted-foreground",
  ready:       "bg-primary text-primary-foreground",
  in_progress: "bg-primary text-primary-foreground",
  completed:   "bg-muted text-muted-foreground",
  failed:      "border border-destructive text-destructive",
};

const TYPE_LABEL: Record<string, string> = {
  quick:    "Quick",
  targeted: "Job-Targeted",
};

async function PlanList() {
  const plans = await listPrepPlans();

  if (plans.length === 0) {
    return (
      <div className="empty-state py-16">
        <Briefcase aria-hidden className="h-12 w-12 text-muted-foreground" />
        <p className="mt-3 text-sm text-muted-foreground">
          No sessions yet. Start a quick practice drill or paste a job description for a scored mock test.
        </p>
        <Button asChild className="mt-4">
          <Link href={ROUTES.INTERVIEW_PREP_NEW}>Get started</Link>
        </Button>
      </div>
    );
  }

  return (
    <ol aria-label="Interview prep plans" className="flex flex-col gap-3">
      {plans.map((plan) => {
        const isQuick = plan.plan_type === "quick";
        return (
          <li key={plan.id}>
            <Link
              className="card-interactive flex items-center gap-4 p-4"
              href={ROUTES.interviewPrepPlan(plan.id)}
            >
              <div className="flex flex-1 flex-col gap-1">
                <div className="flex items-center gap-2">
                  <span className="font-medium">{plan.job_title}</span>
                  <Badge variant="secondary">{TYPE_LABEL[plan.plan_type] ?? plan.plan_type}</Badge>
                  <Badge className={STATUS_BADGE[plan.status] ?? ""} variant="outline">
                    {plan.status.replace("_", " ")}
                  </Badge>
                </div>
                <div className="flex gap-3 text-xs text-muted-foreground">
                  {isQuick ? (
                    <span className="capitalize">{plan.difficulty}</span>
                  ) : (
                    <>
                      <span className="capitalize">{plan.extracted_seniority}</span>
                      <span>{plan.extracted_skills.slice(0, 4).join(", ")}</span>
                    </>
                  )}
                  <span>{new Date(plan.created_at).toLocaleDateString()}</span>
                </div>
              </div>
              {plan.report && (
                <div className="flex flex-col items-end">
                  <span className="text-lg font-bold text-primary">{Math.round(plan.report.readiness_score)}</span>
                  <span className="text-xs text-muted-foreground">readiness</span>
                </div>
              )}
            </Link>
          </li>
        );
      })}
    </ol>
  );
}

export default function InterviewPrepPage() {
  return (
    <main className="page-container py-8">
      <div className="page-header">
        <h1 className="page-title">Interview Prep</h1>
        <Button asChild>
          <Link href={ROUTES.INTERVIEW_PREP_NEW}>
            <Plus aria-hidden className="mr-2 h-4 w-4" />
            New plan
          </Link>
        </Button>
      </div>
      <Suspense fallback={<Skeleton className="h-64 rounded-lg" />}>
        <PlanList />
      </Suspense>
    </main>
  );
}
