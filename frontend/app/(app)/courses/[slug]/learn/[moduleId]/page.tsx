import { notFound } from "next/navigation";
import { authHeaders } from "@/lib/server/api";
import { getCourses, getCourseTree, getCourseProgress } from "@/lib/server/courses";
import { CourseSidebar } from "@/components/courses/course-sidebar";
import { ModuleVideo } from "@/components/courses/module-video";
import { ModulePDF } from "@/components/courses/module-pdf";
import { ModuleNotes } from "@/components/courses/module-notes";
import { ModuleAssessment } from "@/components/courses/module-assessment";

interface Props {
  params: Promise<{ slug: string; moduleId: string }>;
}

interface ModuleContent {
  module_id: string;
  presigned_url?: string;
}

async function getModuleContent(moduleId: string): Promise<ModuleContent | null> {
  const api = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!api) return null;
  const headers = await authHeaders();
  const res = await fetch(`${api}/api/modules/${moduleId}/content`, { headers, cache: "no-store" });
  if (!res.ok) return null;
  const body: { data: ModuleContent } = await res.json();
  return body.data;
}

export async function generateMetadata({ params }: Props) {
  const { slug } = await params;
  return { title: `Learn ${slug} — MindForge` };
}

export default async function ModuleLearnPage({ params }: Props) {
  const { slug, moduleId } = await params;

  const courses = await getCourses();
  const course = courses.find((c) => c.slug === slug);
  if (!course) notFound();

  const [tree, progress, content] = await Promise.all([
    getCourseTree(course.id),
    getCourseProgress(course.id).catch(() => null),
    getModuleContent(moduleId),
  ]);

  const allModules = tree.sections.flatMap((s) => s.modules);
  const currentModule = allModules.find((m) => m.id === moduleId);
  if (!currentModule) notFound();

  const progressModules = progress?.modules ?? [];
  const moduleProgress = progressModules.find((p) => p.module_id === moduleId);

  return (
    <div className="flex min-h-dvh flex-col lg:flex-row">
      <aside className="hidden w-72 shrink-0 border-r border-border lg:block overflow-y-auto">
        <CourseSidebar
          course={{ ...tree, slug }}
          currentModuleId={moduleId}
          progress={progressModules}
        />
      </aside>

      <main className="flex-1 overflow-y-auto">
        <div className="page-container-sm py-8">
          {currentModule.type === "video" && content?.presigned_url && (
            <ModuleVideo
              initialPositionSeconds={moduleProgress?.last_position_seconds}
              moduleId={moduleId}
              presignedUrl={content.presigned_url}
              title={currentModule.title}
            />
          )}
          {currentModule.type === "pdf" && content?.presigned_url && (
            <ModulePDF
              moduleId={moduleId}
              presignedUrl={content.presigned_url}
              title={currentModule.title}
            />
          )}
          {currentModule.type === "notes" && currentModule.content_body && (
            <ModuleNotes
              body={currentModule.content_body}
              moduleId={moduleId}
              title={currentModule.title}
            />
          )}
          {currentModule.type === "assessment" && currentModule.assessment_id && (
            <ModuleAssessment
              assessmentId={currentModule.assessment_id}
              moduleId={moduleId}
              title={currentModule.title}
            />
          )}
          {!content?.presigned_url && currentModule.type !== "notes" && currentModule.type !== "assessment" && (
            <div className="empty-state py-16">
              <p className="text-sm text-muted-foreground">Content is not available yet.</p>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
