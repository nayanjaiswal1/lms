import type { Metadata } from "next";

import { Breadcrumb } from "@/components/shared/breadcrumb";
import { CreateAssessmentForm } from "@/app/(app)/assessments/create-assessment-form";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "New Assessment",
};

export default function NewAssessmentPage() {
  return (
    <main className="page-container">
      <Breadcrumb items={[{ label: "Assessments", href: ROUTES.ASSESSMENTS }, { label: "New" }]} />
      <header className="mb-6 flex flex-col gap-1">
        <h1 className="section-title">New assessment</h1>
        <p className="text-muted-foreground">Configure the test, then add questions and assign it.</p>
      </header>
      <CreateAssessmentForm />
    </main>
  );
}
