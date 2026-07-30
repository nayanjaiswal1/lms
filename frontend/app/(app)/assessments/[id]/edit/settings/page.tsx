import { notFound } from "next/navigation";

import { getAssessment } from "@/lib/assessments/server";
import { EditAssessmentSettingsForm } from "@/app/(app)/assessments/[id]/edit/edit-assessment-settings-form";

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function AssessmentSettingsPage({ params }: PageProps) {
  const { id } = await params;

  let detail: Awaited<ReturnType<typeof getAssessment>>;
  try {
    detail = await getAssessment(id);
  } catch {
    notFound();
  }

  return <EditAssessmentSettingsForm assessment={detail.assessment} />;
}
