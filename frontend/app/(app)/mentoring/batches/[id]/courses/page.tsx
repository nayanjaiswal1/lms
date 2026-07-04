import Link from "next/link";
import { getBatchCourses } from "@/lib/server/batches";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ id: string }>;
}

export default async function MentorBatchCoursesPage({ params }: Props) {
  const { id } = await params;
  const courses = await getBatchCourses(id).catch(() => []);

  return (
    <div className="flex flex-col gap-3">
      {courses.length === 0 ? (
        <p className="text-sm text-muted-foreground">No courses assigned yet.</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {courses.map((c) => (
            <li key={c.course_id} className="card-base flex items-center gap-4 p-4">
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
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
