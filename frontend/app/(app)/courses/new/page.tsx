import { CourseWizard } from "@/components/courses/course-wizard";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import ROUTES from "@/lib/routes";
import { PageHeader } from "@/components/shared/page-header";

export const metadata = { title: "New Course" };

export default function NewCoursePage() {
  return (
    <main className="page-container">
      <Breadcrumb items={[{ label: "Teach", href: ROUTES.TEACH }, { label: "New" }]} />

      <PageHeader title="Create a New Course">
        <p className="text-muted-foreground text-sm">
          Build your course structure, add content blocks, then publish when ready.
        </p>
      </PageHeader>
      <CourseWizard />
    </main>
  );
}
