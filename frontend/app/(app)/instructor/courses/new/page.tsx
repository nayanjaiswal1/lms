import { CourseBuilder } from "@/components/instructor/course-builder";
import { AIOutlinePanel } from "@/components/instructor/ai-outline-panel";

export const metadata = { title: "New Course — MindForge" };

export default function NewCoursePage() {
  return (
    <main className="page-container py-8">
      <div className="page-header">
        <h1 className="page-title">Create a New Course</h1>
      </div>

      <div className="flex flex-col gap-8 lg:flex-row lg:gap-10">
        <div className="flex-1">
          <CourseBuilder />
        </div>
        <aside className="w-full lg:w-80">
          <AIOutlinePanel />
        </aside>
      </div>
    </main>
  );
}
