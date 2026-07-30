import Link from "next/link";
import { notFound } from "next/navigation";
import { getPrepPlan, getPrepReport } from "@/lib/server/interview-prep";
import { ReportCard } from "@/components/interview-prep/report-card";
import { Button } from "@/components/ui/button";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ planId: string }>;
}

export const metadata = { title: "Readiness Report — MindForge" };

export default async function InterviewPrepReportPage({ params }: Props) {
  const { planId } = await params;

  const plan = await getPrepPlan(planId).catch(() => null);
  if (!plan) notFound();

  const report = plan.plan_type === "quick" ? null : plan.report ?? (await getPrepReport(planId).catch(() => null));

  return (
    <main className="page-container-sm">
      <Breadcrumb
        items={[
          { href: ROUTES.INTERVIEW_PREP, label: "Interview Prep" },
          { href: ROUTES.interviewPrepPlan(planId), label: plan.job_title },
          { label: "Report" },
        ]}
      />
      <div className="flex flex-col gap-1 mb-6">
        <h1 className="section-title">Readiness Report</h1>
        <p className="text-sm text-muted-foreground">{plan.job_title}</p>
      </div>

      {report ? (
        <ReportCard jobTitle={plan.job_title} report={report} />
      ) : (
        <div className="empty-state py-16">
          <p className="text-sm text-muted-foreground">
            {plan.plan_type === "quick"
              ? "Quick practice sessions don't generate a readiness report."
              : "Complete both rounds before viewing your readiness report."}
          </p>
          <Button asChild className="mt-4">
            <Link href={ROUTES.interviewPrepPlan(planId)}>Back to plan</Link>
          </Button>
        </div>
      )}
    </main>
  );
}
