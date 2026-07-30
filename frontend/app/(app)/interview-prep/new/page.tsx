import { NewPlanForm } from "@/components/interview-prep/new-plan-form";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import ROUTES from "@/lib/routes";

export const metadata = { title: "New Interview Prep Plan — MindForge" };

export default function NewInterviewPrepPage() {
  return (
    <main className="page-container-sm">
      <Breadcrumb items={[{ href: ROUTES.INTERVIEW_PREP, label: "Interview Prep" }, { label: "New" }]} />
      <div className="page-header">
        <h1 className="section-title">New Interview Prep Plan</h1>
      </div>
      <p className="mb-8 text-muted-foreground">
        Type a topic for a quick practice drill, or paste a job title/description for a full scored
        mock test — we&apos;ll figure out which one you mean.
      </p>
      <NewPlanForm />
    </main>
  );
}
