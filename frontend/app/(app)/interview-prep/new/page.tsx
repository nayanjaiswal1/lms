import { NewPlanForm } from "@/components/interview-prep/new-plan-form";

export const metadata = { title: "New Interview Prep Plan — MindForge" };

export default function NewInterviewPrepPage() {
  return (
    <main className="page-container-sm py-10">
      <div className="page-header">
        <h1 className="page-title">New Interview Prep Plan</h1>
      </div>
      <p className="mb-8 text-muted-foreground">
        Paste a job title or full job description. AI will build a scored mock test — a conceptual
        round and a coding round — tailored to the role.
      </p>
      <NewPlanForm />
    </main>
  );
}
