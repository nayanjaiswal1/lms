import Link from "next/link";
import { notFound } from "next/navigation";
import { getPrepPlan, getPrepReport } from "@/lib/server/interview-prep";
import { ReportCard } from "@/components/interview-prep/report-card";
import { Button } from "@/components/ui/button";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ planId: string }>;
}

export const metadata = { title: "Readiness Report — MindForge" };

export default async function InterviewPrepReportPage({ params }: Props) {
  const { planId } = await params;

  const plan = await getPrepPlan(planId).catch(() => null);
  if (!plan) notFound();

  const report = plan.report ?? (await getPrepReport(planId).catch(() => null));

  return (
    <main className="page-container-sm py-8">
      <div className="flex flex-col gap-1 mb-6">
        <h1 className="page-title">Readiness Report</h1>
        <p className="text-sm text-muted-foreground">{plan.job_title}</p>
      </div>

      {report ? (
        <ReportCard jobTitle={plan.job_title} report={report} />
      ) : (
        <div className="empty-state py-16">
          <p className="text-sm text-muted-foreground">
            Complete both rounds before viewing your readiness report.
          </p>
          <Button asChild className="mt-4">
            <Link href={ROUTES.interviewPrepPlan(planId)}>Back to plan</Link>
          </Button>
        </div>
      )}
    </main>
  );
}
