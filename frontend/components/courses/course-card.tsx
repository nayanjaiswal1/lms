import Link from "next/link";
import type { CSSProperties } from "react";
import { BookOpen, Clock, Star } from "lucide-react";
import type { Course } from "@/lib/server/courses";
import ROUTES from "@/lib/routes";

interface CourseCardProps {
  course: Course;
  enrolled?: boolean;
  progressPct?: number;
  href?: string;
}

export function CourseCard({ course, enrolled, progressPct, href }: CourseCardProps) {
  const showProgress = enrolled && progressPct !== undefined;

  return (
    <article className="card-interactive relative flex flex-col overflow-hidden p-0">
      {/* Full-bleed media — card corners clip it, no inner frame */}
      {/* 2:1 cover — shorter than 16:9, keeps the grid row compact */}
      <div className="relative aspect-[2/1] w-full bg-muted">
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
      </div>

      <div className="flex flex-1 flex-col gap-1.5 p-4">
        <Link
          href={href ?? ROUTES.course(course.slug)}
          className="line-clamp-2 text-sm font-semibold leading-snug after:absolute after:inset-0 after:content-['']"
        >
          {course.title}
        </Link>

        {course.instructor_name && (
          <p className="truncate text-xs text-muted-foreground">By {course.instructor_name}</p>
        )}

        {/* Spacer so footers align across the grid regardless of title length */}
        <div className="flex-1" />

        <div className="flex items-center gap-3 text-xs text-muted-foreground">
          {course.avg_rating !== null && (
            <span className="flex items-center gap-1">
              <Star aria-hidden className="h-3.5 w-3.5 fill-primary text-primary" />
              <span className="font-bold text-primary">{course.avg_rating.toFixed(1)}</span>
              <span>({course.review_count})</span>
            </span>
          )}

          {course.estimated_hours && (
            <span className="flex items-center gap-1">
              <Clock aria-hidden className="h-3.5 w-3.5" />
              {course.estimated_hours}h
            </span>
          )}

          {!enrolled && (
            <span className="ml-auto text-sm font-bold text-foreground">
              {course.is_free ? "Free" : `$${(course.price_cents / 100).toFixed(2)}`}
            </span>
          )}
        </div>

        {showProgress && (
          <div className="flex flex-col gap-1.5 pt-1">
            <div className="flex items-center justify-between text-xs">
              <span className="text-muted-foreground">{progressPct}% complete</span>
              <span className="font-semibold text-primary">
                {progressPct === 0 ? "Start" : progressPct === 100 ? "Review" : "Continue"}
                <span aria-hidden> →</span>
              </span>
            </div>
            <div className="progress-track">
              {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width needs inline style */}
              <div className="progress-fill" style={{ "--progress": `${progressPct}%` } as CSSProperties} />
            </div>
          </div>
        )}
      </div>
    </article>
  );
}
