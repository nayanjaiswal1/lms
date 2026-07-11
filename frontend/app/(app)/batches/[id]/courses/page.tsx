import Link from "next/link";
import { BookOpen } from "lucide-react";
import { getBatchCourses } from "@/lib/server/batches";
import { getCourses } from "@/lib/server/courses";
import { AssignCoursePanel } from "@/components/batches/assign-course-panel";
import { UnassignCourseButton } from "@/components/batches/unassign-course-button";
import { Badge } from "@/components/ui/badge";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ id: string }>;
}

export default async function BatchCoursesPage({ params }: Props) {
  const { id } = await params;
  const [courses, allCourses] = await Promise.all([
    getBatchCourses(id).catch(() => []),
    getCourses().catch(() => []),
  ]);

  return (
    <section className="flex flex-col gap-6">
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <div className="flex items-center gap-2">
          <BookOpen aria-hidden className="h-5 w-5 text-muted-foreground" />
          <h2 className="section-title">Courses</h2>
          <Badge variant="secondary">{courses.length}</Badge>
        </div>
        <AssignCoursePanel
          assignedCourseIds={courses.map((c) => c.course_id)}
          batchId={id}
          courses={allCourses}
        />
      </div>

      {courses.length === 0 ? (
        <div className="empty-state py-12">
          <BookOpen aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="mt-3 font-medium">No courses assigned yet</p>
          <p className="text-sm text-muted-foreground">
            Use the &ldquo;Assign course&rdquo; button to add courses to this batch.
          </p>
        </div>
      ) : (
        <ul className="flex flex-col gap-2">
          {courses.map((c) => (
            <li className="card-interactive flex items-center gap-4 p-4" key={c.course_id}>
              <Link
                className="flex flex-1 flex-col gap-0.5 hover:underline min-w-0"
                href={`${ROUTES.course(c.slug)}?batchId=${id}`}
              >
                <span className="font-medium truncate">{c.title}</span>
                <span className="text-xs capitalize text-muted-foreground">{c.difficulty}</span>
              </Link>
              <span className="text-xs text-muted-foreground whitespace-nowrap">
                {c.assigned_at ? `Assigned ${new Date(c.assigned_at).toLocaleDateString()}` : ""}
              </span>
              <UnassignCourseButton batchId={id} courseId={c.course_id} courseTitle={c.title} />
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
