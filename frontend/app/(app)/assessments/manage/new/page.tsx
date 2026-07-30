import type { Metadata } from "next";

import { CreateAssessmentForm } from "@/app/(app)/assessments/manage/create-assessment-form";
import { ASSESSMENT_PARENT_TYPE } from "@/lib/constants";

export const metadata: Metadata = {
  title: "New Assessment",
};

interface NewAssessmentPageProps {
  searchParams: Promise<{ type?: string }>;
}

export default async function NewAssessmentPage({ searchParams }: NewAssessmentPageProps) {
  const { type } = await searchParams;
  const defaultParentType = type === ASSESSMENT_PARENT_TYPE.HIRING ? ASSESSMENT_PARENT_TYPE.HIRING : undefined;

  return (
    <main className="page-container">
      <header className="mb-6 flex flex-col gap-1">
        <h1 className="page-title">New assessment</h1>
        <p className="text-muted-foreground">Configure the test, then add questions and assign it.</p>
      </header>
      <CreateAssessmentForm defaultParentType={defaultParentType} />
    </main>
  );
}
