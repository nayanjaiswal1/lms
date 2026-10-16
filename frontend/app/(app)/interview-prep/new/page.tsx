import { NewPlanForm } from "@/components/interview-prep/new-plan-form";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import ROUTES from "@/lib/routes";
import { PageHeader } from "@/components/shared/page-header";

export const metadata = { title: "New Interview Prep Plan" };

export default function NewInterviewPrepPage() {
  return (
    <main className="page-container-sm">
      <Breadcrumb items={[{ href: ROUTES.INTERVIEW_PREP, label: "Interview Prep" }, { label: "New" }]} />
      <PageHeader title="New Interview Prep Plan" />
      <p className="mb-8 text-muted-foreground">
        Type a topic for a quick practice drill, or paste a job title/description for a full scored
        mock test — we&apos;ll figure out which one you mean.
      </p>
      <NewPlanForm />
    </main>
  );
}
