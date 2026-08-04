import { notFound } from "next/navigation";
import { getPrepPlan } from "@/lib/server/interview-prep";
import { RoundList } from "@/components/interview-prep/round-list";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ planId: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { planId } = await params;
  const plan = await getPrepPlan(planId).catch(() => null);
  if (!plan) return { title: "Interview Prep" };
  return { title: `${plan.job_title} prep` };
}

export default async function InterviewPrepPlanPage({ params }: Props) {
  const { planId } = await params;
  const plan = await getPrepPlan(planId).catch(() => null);
  if (!plan) notFound();

  return (
    <main className="page-container-sm">
      <Breadcrumb
        items={[{ href: ROUTES.INTERVIEW_PREP, label: "Interview Prep" }, { label: plan.job_title }]}
      />
      <div className="flex flex-col gap-1 mb-6">
        <h1 className="section-title">{plan.job_title}</h1>
        <p className="text-sm text-muted-foreground">
          Created {new Date(plan.created_at).toLocaleDateString()}
        </p>
      </div>
      <RoundList plan={plan} />
    </main>
  );
}
