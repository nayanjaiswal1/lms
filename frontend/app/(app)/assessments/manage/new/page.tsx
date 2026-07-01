import type { Metadata } from "next";

import { CreateAssessmentForm } from "@/app/(app)/assessments/manage/create-assessment-form";

export const metadata: Metadata = {
  title: "New Assessment",
};

export default function NewAssessmentPage() {
  return (
    <main className="page-container-sm py-10">
      <header className="mb-6 flex flex-col gap-1">
        <h1 className="page-title">New assessment</h1>
        <p className="text-muted-foreground">Configure the test, then add questions and assign it.</p>
      </header>
      <div className="card-base p-6">
        <CreateAssessmentForm />
      </div>
    </main>
  );
}
