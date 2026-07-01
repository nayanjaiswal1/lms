import { CreateCourseWizard } from "@/components/instructor/create-course-wizard";

export const metadata = { title: "New Course — MindForge" };

export default function NewCoursePage() {
  return (
    <main className="page-container py-8">
      <div className="page-header mb-6">
        <h1 className="page-title">Create a New Course</h1>
        <p className="text-muted-foreground text-sm">
          Build your course structure, add content blocks, then publish when ready.
        </p>
      </div>
      <CreateCourseWizard />
    </main>
  );
}
