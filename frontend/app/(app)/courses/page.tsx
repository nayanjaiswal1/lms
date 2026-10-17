import { redirect } from "next/navigation";
import Link from "next/link";
import { Compass } from "lucide-react";
import { Button } from "@/components/ui/button";
import { CatalogPage } from "@/components/courses/catalog-page";
import { CourseFilters, filterAndSortCourses, hasActiveFilters, parseCourseFilters } from "@/components/courses/course-filters";
import { CourseCard } from "@/components/courses/course-card";
import { PageHeader } from "@/components/shared/page-header";
import { getEnrollments } from "@/lib/server/courses";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import ROUTES from "@/lib/routes";

export const metadata = { title: "Courses" };

type SearchParams = Promise<Record<string, string | undefined>>;

// Instructors/admins manage the full catalog here. Students see only their
// enrolled courses, with a way out to the catalog; none enrolled -> straight
// to the catalog.
export default async function CoursesPage({ searchParams }: { searchParams: SearchParams }) {
  const permissions = await getMyPermissions();
  if (permissions.includes(PERMISSIONS.COURSES.CREATE)) {
    return <CatalogPage basePath={ROUTES.COURSES} searchParams={searchParams} />;
  }

  const enrollments = await getEnrollments();
  if (enrollments.length === 0) redirect(ROUTES.COURSES_BROWSE);

  const raw = await searchParams;
  const filters = parseCourseFilters(raw);
  const byCourse = new Map(enrollments.map((e) => [e.course_id, e]));
  // Default order is last activity; an explicit ?sort= switches to course ordering.
  const matched = filterAndSortCourses(
    enrollments.map((e) => e.course),
    filters,
    new Set(byCourse.keys()),
  );
  const mine = (
    raw.sort ? matched.map((c) => byCourse.get(c.id)) : enrollments.filter((e) => matched.some((c) => c.id === e.course_id))
  ).filter((e): e is NonNullable<typeof e> => Boolean(e));
  if (!raw.sort) {
    mine.sort((a, b) =>
      (b.progress.last_activity_at ?? b.enrolled_at).localeCompare(a.progress.last_activity_at ?? a.enrolled_at),
    );
  }

  return (
    <main className="page-container">
      <PageHeader description="Courses you are enrolled in." title="My courses">
        <Button asChild variant="outline">
          <Link href={ROUTES.COURSES_BROWSE}>
            <Compass aria-hidden className="mr-2 h-4 w-4" />
            Browse other courses
          </Link>
        </Button>
      </PageHeader>
      <CourseFilters basePath={ROUTES.COURSES} fields={["difficulty", "sort"]} filters={filters} />
      {mine.length === 0 ? (
        <p className="py-16 text-center text-sm text-muted-foreground">
          No enrolled course matches{hasActiveFilters(filters) ? " these filters" : ""}.
        </p>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {mine.map((e) => (
            <CourseCard course={e.course} enrolled key={e.id} progress={e.progress} progressPct={e.progress.pct} />
          ))}
        </div>
      )}
    </main>
  );
}
