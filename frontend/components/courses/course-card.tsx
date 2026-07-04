import Link from "next/link";
import { BookOpen, CheckCircle2, Clock, Star } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { CourseProgressRing } from "@/components/courses/course-progress-ring";
import type { Course } from "@/lib/server/courses";
import ROUTES from "@/lib/routes";

interface CourseCardProps {
  course: Course;
  enrolled?: boolean;
  progressPct?: number;
  href?: string;
}

const DIFFICULTY_CLASS: Record<string, string> = {
  beginner:     "difficulty-beginner",
  intermediate: "difficulty-intermediate",
  advanced:     "difficulty-advanced",
  expert:       "difficulty-expert",
};

export function CourseCard({ course, enrolled, progressPct, href }: CourseCardProps) {
  return (
    <article className="card-interactive relative flex flex-col gap-2 p-6">
      <div className="relative aspect-video w-full overflow-hidden rounded-lg bg-muted">
        {course.cover_url ? (
          // eslint-disable-next-line @next/next/no-img-element -- dynamic remote cover, no known dimensions (same convention as course detail page)
          <img
            alt={course.title}
            className="absolute inset-0 h-full w-full object-cover"
            loading="lazy"
            src={course.cover_url}
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center">
            <BookOpen aria-hidden className="h-10 w-10 text-muted-foreground" />
          </div>
        )}
        <Badge
          variant="outline"
          className={`absolute right-2 top-2 z-raised ${DIFFICULTY_CLASS[course.difficulty]}`}
        >
          {course.difficulty}
        </Badge>
        {enrolled && (
          <Badge variant="outline" className="badge-success absolute left-2 top-2 z-raised">
            <CheckCircle2 aria-hidden className="h-3 w-3" />
            Enrolled
          </Badge>
        )}
      </div>

      <Link
        href={href ?? ROUTES.course(course.slug)}
        className="line-clamp-2 text-base font-semibold leading-snug after:absolute after:inset-0 after:content-['']"
      >
        {course.title}
      </Link>

      {course.instructor_name && (
        <p className="truncate text-xs text-muted-foreground">By {course.instructor_name}</p>
      )}

      <div className="flex items-center justify-between gap-2 text-xs">
        {course.avg_rating !== null ? (
          <div className="flex items-center gap-1">
            <Star aria-hidden className="h-3.5 w-3.5 fill-primary text-primary" />
            <span className="font-bold text-primary">{course.avg_rating.toFixed(1)}</span>
            <span className="text-muted-foreground">({course.review_count})</span>
          </div>
        ) : (
          <p className="text-muted-foreground">New</p>
        )}

        {enrolled && progressPct !== undefined ? (
          <span className="flex items-center gap-1.5 text-muted-foreground">
            <CourseProgressRing pct={progressPct} />
            {progressPct}% complete
          </span>
        ) : (
          <span className="flex items-center gap-1 text-sm font-bold text-foreground">
            {course.is_free ? "Free" : `$${(course.price_cents / 100).toFixed(2)}`}
          </span>
        )}
      </div>

      {course.estimated_hours && (
        <span className="flex items-center gap-1 text-xs text-muted-foreground">
          <Clock aria-hidden className="h-3.5 w-3.5" />
          {course.estimated_hours}h
        </span>
      )}
    </article>
  );
}
