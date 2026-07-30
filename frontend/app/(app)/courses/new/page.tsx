import { CourseWizard } from "@/components/courses/course-wizard";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import ROUTES from "@/lib/routes";

export const metadata = { title: "New Course — MindForge" };

export default function NewCoursePage() {
  return (
    <main className="page-container">
      <Breadcrumb items={[{ label: "Teach", href: ROUTES.TEACH }, { label: "New" }]} />

      <div className="page-header mb-6">
        <h1 className="section-title">Create a New Course</h1>
        <p className="text-muted-foreground text-sm">
          Build your course structure, add content blocks, then publish when ready.
        </p>
      </div>
      <CourseWizard />
    </main>
  );
}
