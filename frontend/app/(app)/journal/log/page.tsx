import { redirect } from "next/navigation";

import ROUTES from "@/lib/routes";
import { getOrCreateLearningLogCourse } from "@/lib/server/courses";

// Thin entry point only — reuses the existing course-viewer pages
// (courses/[slug]/learn) rather than a parallel "Learn" UI. The Learning Log
// is a self-course like any other; internal/diary's "learned" highlights and
// a manual visit here both land in the same place.
export default async function JournalLogPage() {
  const course = await getOrCreateLearningLogCourse();
  redirect(ROUTES.courseLearn(course.slug));
}
