import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { getAssessment, getQuestions, getBatches } from "@/lib/server/assessments";
import { AssessmentBuilder } from "@/app/instructor/assessments/[id]/assessment-builder";

export const metadata: Metadata = {
  title: "Edit Assessment",
};

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function AssessmentBuilderPage({ params }: PageProps) {
  const { id } = await params;

  let detail: Awaited<ReturnType<typeof getAssessment>>;
  try {
    detail = await getAssessment(id);
  } catch {
    notFound();
  }

  const [bank, batches] = await Promise.all([getQuestions("?limit=100"), getBatches()]);

  return (
    <AssessmentBuilder
      assessment={detail.assessment}
      attached={detail.questions}
      bank={bank.questions}
      batches={batches}
    />
  );
}
