import { BookOpen } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import type { Enrollment } from "@/app/(app)/users/[id]/types";

function EnrollmentCard({ enrollment }: { enrollment: Enrollment }) {
  const { course, progress } = enrollment;
  return (
    <div className="card-base p-4 flex gap-4">
      <div className="h-14 w-14 shrink-0 rounded-md bg-muted overflow-hidden flex items-center justify-center">
        {course.cover_url ? (
          // eslint-disable-next-line @next/next/no-img-element -- dynamic remote cover, no known dimensions (same convention as components/courses/course-card.tsx)
          <img alt={course.title} className="h-full w-full object-cover" loading="lazy" src={course.cover_url} />
        ) : (
          <BookOpen aria-hidden className="h-6 w-6 text-muted-foreground" />
        )}
      </div>

      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2 min-w-0">
          <p className="text-sm font-medium text-foreground truncate">{course.title}</p>
          {enrollment.completed_at && <Badge variant="secondary">Completed</Badge>}
        </div>
        <p className="text-xs text-muted-foreground mt-0.5 capitalize">{course.difficulty}</p>

        <div className="mt-2 flex items-center gap-2">
          <div className="progress-track flex-1">
            {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width needs inline style */}
            <div className="progress-fill" style={{ "--progress": `${progress.pct}%` } as React.CSSProperties} />
          </div>
          <span className="text-xs text-muted-foreground shrink-0">
            {progress.completed}/{progress.total}
          </span>
        </div>

        <p className="text-xs text-muted-foreground mt-1.5">
          {progress.last_activity_at
            ? `Last activity ${new Date(progress.last_activity_at).toLocaleDateString()}`
            : `Enrolled ${new Date(enrollment.enrolled_at).toLocaleDateString()}`}
        </p>
      </div>
    </div>
  );
}

export function CoursesTab({ enrollments }: { enrollments: Enrollment[] }) {
  if (enrollments.length === 0) {
    return (
      <div className="empty-state">
        <BookOpen aria-hidden className="empty-state-icon" />
        <p>Not enrolled in any courses.</p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {enrollments.map((e) => (
        <EnrollmentCard enrollment={e} key={e.id} />
      ))}
    </div>
  );
}
