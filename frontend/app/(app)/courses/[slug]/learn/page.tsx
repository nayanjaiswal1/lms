import { notFound, redirect } from "next/navigation";
import { findCourseBySlug, getCourses, getCourseProgress, getCourseTree, getEnrollments } from "@/lib/server/courses";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ slug: string }>;
}

export default async function CourseLearnIndexPage({ params }: Props) {
  const { slug } = await params;

  const [courses, enrollments] = await Promise.all([getCourses(), getEnrollments()]);
  const course = findCourseBySlug(courses, enrollments, slug);
  if (!course) notFound();

  const [tree, progress] = await Promise.all([
    getCourseTree(course.id).catch(() => null),
    getCourseProgress(course.id).catch(() => null),
  ]);
  const allModules = tree?.sections?.flatMap((s) => s.modules) ?? [];
  if (allModules.length === 0) notFound();

  const completedIDs = new Set(
    (progress?.modules ?? []).filter((p) => p.status === "completed").map((p) => p.module_id),
  );
  const resumeModule = allModules.find((m) => !completedIDs.has(m.id)) ?? allModules[allModules.length - 1];

  redirect(ROUTES.courseLearnModule(slug, resumeModule.id));
}
