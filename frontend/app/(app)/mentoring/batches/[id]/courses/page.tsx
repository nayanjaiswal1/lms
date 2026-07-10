import Link from "next/link";
import { getBatchCourses } from "@/lib/server/batches";
import { getCourses } from "@/lib/server/courses";
import { AssignCoursePanel } from "@/components/batches/assign-course-panel";
import { UnassignCourseButton } from "@/components/batches/unassign-course-button";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ id: string }>;
}

export default async function MentorBatchCoursesPage({ params }: Props) {
  const { id } = await params;
  const [courses, allCourses] = await Promise.all([
    getBatchCourses(id).catch(() => []),
    getCourses().catch(() => []),
  ]);

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-end">
        <AssignCoursePanel
          assignedCourseIds={courses.map((c) => c.course_id)}
          batchId={id}
          courses={allCourses}
        />
      </div>

      {courses.length === 0 ? (
        <p className="text-sm text-muted-foreground">No courses assigned yet.</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {courses.map((c) => (
            <li className="card-base flex items-center gap-4 p-4" key={c.course_id}>
              <Link
                className="flex flex-1 flex-col gap-0.5 hover:underline"
                href={`${ROUTES.course(c.slug)}?batchId=${id}`}
              >
                <span className="font-medium">{c.title}</span>
                <span className="text-xs capitalize text-muted-foreground">{c.difficulty}</span>
              </Link>
              <span className="text-xs text-muted-foreground">
                {c.assigned_at ? `Assigned ${new Date(c.assigned_at).toLocaleDateString()}` : ""}
              </span>
              <UnassignCourseButton batchId={id} courseId={c.course_id} courseTitle={c.title} />
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
