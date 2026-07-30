import { notFound } from "next/navigation";

import { getAssessment, getBatches } from "@/lib/assessments/server";
import { BatchesPanel } from "@/app/(app)/assessments/[id]/edit/batches-panel";

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function AssessmentBatchesPage({ params }: PageProps) {
  const { id } = await params;

  let detail: Awaited<ReturnType<typeof getAssessment>>;
  try {
    detail = await getAssessment(id);
  } catch {
    notFound();
  }
  const batches = await getBatches();

  return <BatchesPanel assessment={detail.assessment} batches={batches} />;
}
