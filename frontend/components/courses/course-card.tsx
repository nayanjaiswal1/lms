import Link from "next/link";
import { BookOpen, Clock, GraduationCap } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import type { Course } from "@/lib/server/courses";
import ROUTES from "@/lib/routes";

interface CourseCardProps {
  course: Course;
  enrolled?: boolean;
  progressPct?: number;
}

const DIFFICULTY_CLASS: Record<string, string> = {
  beginner:     "difficulty-beginner",
  intermediate: "difficulty-intermediate",
  advanced:     "difficulty-advanced",
};

export function CourseCard({ course, enrolled, progressPct }: CourseCardProps) {
  return (
    <article className="card-interactive flex flex-col gap-3 p-6">
      {course.cover_url && (
        <div className="relative h-36 w-full overflow-hidden rounded-lg bg-muted">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={course.cover_url}
            alt={course.title}
            className="h-full w-full object-cover"
          />
        </div>
      )}

      <div className="flex items-start justify-between gap-2">
        <Link
          href={ROUTES.course(course.slug)}
          className="text-base font-semibold leading-snug hover:underline"
        >
          {course.title}
        </Link>
        <span className={DIFFICULTY_CLASS[course.difficulty] ?? ""}>{course.difficulty}</span>
      </div>

      {course.description && (
        <p className="line-clamp-2 text-sm text-muted-foreground">{course.description}</p>
      )}

      <div className="flex flex-wrap gap-2">
        {course.tags.slice(0, 3).map((tag) => (
          <Badge key={tag} variant="secondary" className="text-xs">
            {tag}
          </Badge>
        ))}
      </div>

      <div className="mt-auto flex items-center justify-between gap-2 text-xs text-muted-foreground">
        {course.estimated_hours && (
          <span className="flex items-center gap-1">
            <Clock aria-hidden className="h-3.5 w-3.5" />
            {course.estimated_hours}h
          </span>
        )}
        {enrolled && progressPct !== undefined ? (
          <span className="flex items-center gap-1">
            <GraduationCap aria-hidden className="h-3.5 w-3.5" />
            {progressPct}% complete
          </span>
        ) : (
          <span className="flex items-center gap-1">
            <BookOpen aria-hidden className="h-3.5 w-3.5" />
            {course.is_free ? "Free" : "Paid"}
          </span>
        )}
      </div>

      {enrolled && progressPct !== undefined && (
        <div className="progress-track">
          {/* eslint-disable-next-line no-restricted-syntax -- dynamic width requires inline style */}
          <div className="progress-fill" style={{ "--progress": `${progressPct}%` } as React.CSSProperties} />
        </div>
      )}
    </article>
  );
}
