import { cookies } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { findCourseBySlug, getCourses, getCourseProgress, getCourseTree, getEnrollments, getPublicCourseTree } from "@/lib/server/courses";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ slug: string }>;
}

// Modules docs/anonymous.md's anonymous flow can actually render — used here
// to pick a sensible module to land an anonymous visitor on, falling back to
// the first module of any type when a public course happens to have none.
const ANON_READABLE_TYPES = new Set(["notes", "system_design"]);

export default async function CourseLearnIndexPage({ params }: Props) {
  const { slug } = await params;

  const cookieStore = await cookies();
  if (!cookieStore.get("access_token")?.value) {
    const tree = await getPublicCourseTree(slug);
    if (!tree) notFound();
    const allModules = tree.sections.flatMap((s) => s.modules);
    if (allModules.length === 0) notFound();
    const landingModule = allModules.find((m) => ANON_READABLE_TYPES.has(m.type)) ?? allModules[0];
    redirect(ROUTES.courseLearnModule(slug, landingModule.id));
  }

  const [courses, enrollments] = await Promise.all([getCourses(), getEnrollments()]);
  const course = findCourseBySlug(courses, enrollments, slug);
  if (!course) notFound();

  const [tree, progress] = await Promise.all([
    getCourseTree(course.id).catch(() => null),
    getCourseProgress(course.id).catch(() => null),
  ]);
  const allModules = tree?.sections?.flatMap((s) => s.modules) ?? [];

  if (allModules.length === 0) {
    notFound();
  }

  const completedIDs = new Set(
    (progress?.modules ?? []).filter((p) => p.status === "completed").map((p) => p.module_id),
  );
  const resumeModule = allModules.find((m) => !completedIDs.has(m.id)) ?? allModules[allModules.length - 1];

  redirect(ROUTES.courseLearnModule(slug, resumeModule.id));
}
