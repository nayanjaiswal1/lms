import { NewSessionForm } from "@/components/practice/new-session-form";

export const metadata = { title: "New Practice Session — MindForge" };

export default function NewPracticeSessionPage() {
  return (
    <main className="page-container-sm py-10">
      <div className="page-header">
        <h1 className="page-title">New Practice Session</h1>
      </div>
      <p className="mb-8 text-muted-foreground">
        An AI will generate interview-style questions tailored to your chosen technology and difficulty.
      </p>
      <NewSessionForm />
    </main>
  );
}
