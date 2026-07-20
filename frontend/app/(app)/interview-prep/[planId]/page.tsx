import { notFound } from "next/navigation";
import { getPrepPlan } from "@/lib/server/interview-prep";
import { RoundList } from "@/components/interview-prep/round-list";

interface Props {
  params: Promise<{ planId: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { planId } = await params;
  const plan = await getPrepPlan(planId).catch(() => null);
  if (!plan) return { title: "Interview Prep — MindForge" };
  return { title: `${plan.job_title} prep — MindForge` };
}

export default async function InterviewPrepPlanPage({ params }: Props) {
  const { planId } = await params;
  const plan = await getPrepPlan(planId).catch(() => null);
  if (!plan) notFound();

  return (
    <main className="page-container-sm py-8">
      <div className="flex flex-col gap-1 mb-6">
        <h1 className="page-title">{plan.job_title}</h1>
        <p className="text-sm text-muted-foreground">
          Created {new Date(plan.created_at).toLocaleDateString()}
        </p>
      </div>
      <RoundList plan={plan} />
    </main>
  );
}
