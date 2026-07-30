import type { ReactNode } from "react";
import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { Badge } from "@/components/ui/badge";
import { AssessmentBreadcrumb } from "@/app/(app)/assessments/[id]/edit/assessment-breadcrumb";
import { AssessmentTabsNav } from "@/app/(app)/assessments/[id]/edit/assessment-tabs-nav";
import { PublishAction } from "@/app/(app)/assessments/[id]/edit/publish-action";
import { AssignAction } from "@/app/(app)/assessments/[id]/edit/assign-action";
import { StatusAction } from "@/app/(app)/assessments/[id]/edit/status-action";
import { HeaderStats } from "@/app/(app)/assessments/[id]/edit/header-stats";
import { getAssessment } from "@/lib/assessments/server";

export const metadata: Metadata = {
  title: "Edit Assessment",
};

interface LayoutProps {
  params: Promise<{ id: string }>;
  children: ReactNode;
}

export default async function AssessmentBuilderLayout({ params, children }: LayoutProps) {
  const { id } = await params;

  let detail: Awaited<ReturnType<typeof getAssessment>>;
  try {
    detail = await getAssessment(id);
  } catch {
    notFound();
  }
  const { assessment, questions } = detail;
  const isDraft = assessment.status === "draft";

  return (
    <main className="page-container">
      <AssessmentBreadcrumb assessmentId={id} title={assessment.title} />
      <header className="page-header">
        <div className="flex flex-col gap-2">
          <div className="flex items-center gap-2">
            <h1 className="section-title">{assessment.title}</h1>
            <Badge variant={isDraft ? "outline" : "default"}>{assessment.status}</Badge>
          </div>
          <HeaderStats
            durationMinutes={assessment.duration_minutes}
            questionCount={questions.length}
            totalPoints={assessment.total_points}
          />
        </div>
        <div className="flex items-center gap-2">
          <StatusAction assessmentId={id} status={assessment.status} />
          <PublishAction assessmentId={id} attachedCount={questions.length} isDraft={isDraft} />
          <AssignAction assessmentId={id} />
        </div>
      </header>

      <AssessmentTabsNav assessmentId={id} />

      {children}
    </main>
  );
}
