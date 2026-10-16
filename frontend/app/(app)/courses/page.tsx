import { Suspense } from "react";
import Link from "next/link";
import { BookOpen, Library, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { CourseCard } from "@/components/courses/course-card";
import { RandomTopicCard } from "@/components/courses/random-topic-card";
import { BundleGrid } from "@/components/bundles/bundle-grid";
import { getCourses, getEnrollments, getRandomTopic } from "@/lib/server/courses";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import ROUTES from "@/lib/routes";
import { PageHeader } from "@/components/shared/page-header";

export const metadata = { title: "Courses" };

async function RandomTopic() {
  const topic = await getRandomTopic();
  return <RandomTopicCard initialTopic={topic} />;
}

interface CourseGridProps {
  query: string;
  canManage: boolean;
  canEdit: boolean;
  canViewAnalytics: boolean;
}

async function CourseGrid({ query, canManage, canEdit, canViewAnalytics }: CourseGridProps) {
  const [courses, enrollments, ownCourses] = await Promise.all([
    getCourses(),
    getEnrollments(),
    canManage ? getCourses("?role=instructor") : Promise.resolve([]),
  ]);

  const enrolledMap = new Map(enrollments.map((e) => [e.course_id, e]));
  const ownedIds = new Set(ownCourses.map((c) => c.id));

  // Own drafts don't appear in the published catalog `courses` already covers
  // — append any owned course not already listed there.
  const q = query.toLowerCase();
  const merged = [
    ...courses,
    ...ownCourses.filter((c) => !courses.some((pc) => pc.id === c.id)),
  ].filter(
    (c) =>
      !q ||
      [c.title, c.description ?? "", c.instructor_name, ...c.tags].some((f) => f.toLowerCase().includes(q)),
  );

  if (merged.length === 0) {
    return (
      <div className="empty-state py-16">
        <BookOpen aria-hidden className="h-12 w-12 text-muted-foreground" />
        <p className="mt-3 text-sm text-muted-foreground">
          {q ? `No courses match “${query}”.` : "No courses are available yet."}
        </p>
        {canManage && !q && (
          <Button asChild className="mt-4">
            <Link href={ROUTES.COURSE_NEW}>Create your first course</Link>
          </Button>
        )}
      </div>
    );
  }

  return (
    <div className="card-grid">
      {merged.map((course) => (
        <CourseCard
          canEdit={canEdit}
          canViewAnalytics={canViewAnalytics}
          course={course}
          enrolled={enrolledMap.has(course.id)}
          key={course.id}
          owned={ownedIds.has(course.id)}
        />
      ))}
    </div>
  );
}

function CourseGridSkeleton() {
  return (
    <div className="card-grid">
      {Array.from({ length: 6 }).map((_, i) => (
        <Skeleton className="h-64 rounded-lg" key={i} />
      ))}
    </div>
  );
}

export default async function CoursesPage({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
  const { q = "" } = await searchParams;
  const permissions = await getMyPermissions();
  const canManage = permissions.includes(PERMISSIONS.COURSES.CREATE);
  const canEdit = permissions.includes(PERMISSIONS.COURSES.EDIT);
  const canViewAnalytics = permissions.includes(PERMISSIONS.COURSES.VIEW_ANALYTICS);

  return (
    <main className="page-container">
      <PageHeader title="Courses">
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
      <div className="mb-6">
        <Suspense fallback={<Skeleton className="h-32 rounded-lg" />}>
          <RandomTopic />
        </Suspense>
      </div>
      <Suspense fallback={null}>
        <BundleGrid canManage={canManage} />
      </Suspense>
      <Suspense fallback={<CourseGridSkeleton />} key={q.trim()}>
        <CourseGrid query={q.trim()} canEdit={canEdit} canManage={canManage} canViewAnalytics={canViewAnalytics} />
      </Suspense>
    </main>
  );
}
