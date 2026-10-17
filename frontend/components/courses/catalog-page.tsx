import { Suspense } from "react";
import Link from "next/link";
import { BookOpen, Library, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { CourseCard } from "@/components/courses/course-card";
import {
  BundleGrid,
  BundleGridSkeleton,
} from "@/components/bundles/bundle-grid";
import {
  CourseFilters,
  filterAndSortCourses,
  hasActiveFilters,
  parseCourseFilters,
  type CourseFilterState,
} from "@/components/courses/course-filters";
import {
  getCourses,
  getEnrollments,
  type Enrollment,
} from "@/lib/server/courses";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import ROUTES from "@/lib/routes";
import { PageHeader } from "@/components/shared/page-header";

const CONTINUE_LIMIT = 3;

async function ContinueLearning({
  enrollments,
}: {
  enrollments: Promise<Enrollment[]>;
}) {
  const active = (await enrollments)
    .filter((e) => !e.completed_at && e.progress.pct < 100)
    .sort((a, b) =>
      (b.progress.last_activity_at ?? b.enrolled_at).localeCompare(
        a.progress.last_activity_at ?? a.enrolled_at,
      ),
    )
    .slice(0, CONTINUE_LIMIT);
  if (active.length === 0) return null;

  return (
    <section aria-labelledby="continue-heading" className="mb-8">
      <h2 className="section-title mb-4" id="continue-heading">
        Continue learning
      </h2>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {active.map((e) => (
          <CourseCard
            course={e.course}
            enrolled
            key={e.id}
            progress={e.progress}
            progressPct={e.progress.pct}
          />
        ))}
      </div>
    </section>
  );
}

interface CourseGridProps {
  basePath: string;
  filters: CourseFilterState;
  enrollments: Promise<Enrollment[]>;
  canManage: boolean;
  canEdit: boolean;
  canViewAnalytics: boolean;
}

async function CourseGrid({
  basePath,
  filters,
  enrollments,
  canManage,
  canEdit,
  canViewAnalytics,
}: CourseGridProps) {
  const [courses, enrolled, ownCourses] = await Promise.all([
    getCourses(),
    enrollments,
    canManage ? getCourses("?role=instructor") : Promise.resolve([]),
  ]);

  const enrolledMap = new Map(enrolled.map((e) => [e.course_id, e]));
  const ownedIds = new Set(ownCourses.map((c) => c.id));

  // Own drafts don't appear in the published catalog `courses` already covers
  // — append any owned course not already listed there.
  const merged = filterAndSortCourses(
    [
      ...courses,
      ...ownCourses.filter((c) => !courses.some((pc) => pc.id === c.id)),
    ],
    filters,
    new Set(enrolledMap.keys()),
  );
  const filtered = hasActiveFilters(filters);

  if (merged.length === 0) {
    return (
      <div className="empty-state">
        <BookOpen aria-hidden className="h-12 w-12 text-muted-foreground" />
        <p className="text-sm text-muted-foreground">
          {filtered
            ? "No courses match these filters."
            : "No courses are available yet."}
        </p>
        {filtered ? (
          <Button asChild variant="outline">
            <Link href={basePath}>Clear filters</Link>
          </Button>
        ) : (
          canManage && (
            <Button asChild>
              <Link href={ROUTES.COURSE_NEW}>Create your first course</Link>
            </Button>
          )
        )}
      </div>
    );
  }

  return (
    <>
      <p
        aria-live="polite"
        className="mb-4 flex flex-wrap items-center gap-x-3 text-sm text-muted-foreground"
      >
        <span>
          {merged.length} course{merged.length === 1 ? "" : "s"}
          {filters.q && <> for “{filters.q}”</>}
        </span>
        {filtered && (
          <Link className="text-primary hover:underline" href={basePath}>
            Clear filters
          </Link>
        )}
      </p>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {merged.map((course) => {
          const e = enrolledMap.get(course.id);
          return (
            <CourseCard
              canEdit={canEdit}
              canViewAnalytics={canViewAnalytics}
              course={course}
              enrolled={Boolean(e)}
              key={course.id}
              owned={ownedIds.has(course.id)}
              progress={e?.progress}
              progressPct={e?.progress.pct}
            />
          );
        })}
      </div>
    </>
  );
}

function CourseGridSkeleton() {
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
      {Array.from({ length: 6 }).map((_, i) => (
        <Skeleton className="h-60 rounded-lg" key={i} />
      ))}
    </div>
  );
}

export async function CatalogPage({
  searchParams,
  basePath,
  title = "Courses",
  discovery = true,
}: {
  searchParams: Promise<Record<string, string | undefined>>;
  basePath: string;
  title?: string;
  /** Continue-learning row; off on the browse page, whose job is the catalog only. */
  discovery?: boolean;
}) {
  const filters = parseCourseFilters(await searchParams);
  const permissions = await getMyPermissions();
  const canManage = permissions.includes(PERMISSIONS.COURSES.CREATE);
  const canEdit = permissions.includes(PERMISSIONS.COURSES.EDIT);
  const canViewAnalytics = permissions.includes(
    PERMISSIONS.COURSES.VIEW_ANALYTICS,
  );
  const enrollments = getEnrollments();
  const gridKey = JSON.stringify(filters);

  return (
    <main className="page-container">
      <PageHeader
        description="Browse the catalog and pick up where you left off."
        title={title}
      >
        {canManage && (
          <div className="flex flex-wrap gap-2">
            <Button asChild variant="outline">
              <Link href={ROUTES.BUNDLE_NEW}>
                <Library aria-hidden className="mr-2 h-4 w-4" />
                New bundle
              </Link>
            </Button>
            <Button asChild>
              <Link href={ROUTES.COURSE_NEW}>
                <Plus aria-hidden className="mr-2 h-4 w-4" />
                New course
              </Link>
            </Button>
          </div>
        )}
      </PageHeader>
      {discovery && (
        <>
          <Suspense fallback={null}>
            <ContinueLearning enrollments={enrollments} />
          </Suspense>
        </>
      )}
      <Suspense fallback={<BundleGridSkeleton />}>
        <BundleGrid canManage={canManage} />
      </Suspense>
      {discovery && <h2 className="section-title mb-4">All courses</h2>}
      <CourseFilters basePath={basePath} filters={filters} />
      <Suspense fallback={<CourseGridSkeleton />} key={gridKey}>
        <CourseGrid
          basePath={basePath}
          canEdit={canEdit}
          canManage={canManage}
          canViewAnalytics={canViewAnalytics}
          enrollments={enrollments}
          filters={filters}
        />
      </Suspense>
    </main>
  );
}
