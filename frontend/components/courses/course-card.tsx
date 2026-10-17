import Link from "next/link";
import type { CSSProperties } from "react";
import { BookOpen, Clock, Star } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { ProgressRing } from "@/components/courses/progress-ring";
import { InstructorHover } from "@/components/courses/instructor-hover";
import { ManageCourseMenu } from "@/components/courses/manage-course-menu";
import type { Course } from "@/lib/server/courses";
import { getPaymentsCurrency } from "@/lib/server/payments";
import { formatMoney } from "@/lib/money";
import ROUTES from "@/lib/routes";

interface CourseCardProps {
  course: Course;
  enrolled?: boolean;
  owned?: boolean;
  canEdit?: boolean;
  canViewAnalytics?: boolean;
  progressPct?: number;
  progress?: { completed: number; total: number };
  href?: string;
}

// Async only to read the deployment's currency — getPaymentsCurrency is
// React-cached, so a grid of cards still resolves it once per render.
export async function CourseCard({
  course,
  enrolled,
  owned,
  canEdit,
  canViewAnalytics,
  progressPct,
  progress,
  href,
}: CourseCardProps) {
  const currency = await getPaymentsCurrency();
  const showProgress = enrolled && progressPct !== undefined;
  const showPrice = !owned && !enrolled;

  return (
    <article className="card-interactive relative flex flex-col overflow-hidden p-0">
      {owned && (
        <div className="absolute right-2 top-2 z-dropdown rounded-md bg-background/80 backdrop-blur-sm">
          <ManageCourseMenu
            canEdit={canEdit ?? false}
            canViewAnalytics={canViewAnalytics ?? false}
            courseSlug={course.slug}
            courseTitle={course.title}
            published={course.status === "published"}
          />
        </div>
      )}
      <div className="relative aspect-[5/2] w-full bg-muted">
        <span
          className={`difficulty-${course.difficulty} absolute left-2 top-2 z-raised rounded-full border bg-background/80 px-2 py-0.5 text-xs font-medium capitalize backdrop-blur-sm`}
        >
          {course.difficulty}
        </span>
        {course.cover_url ? (
          // oxlint-disable-next-line @next/next/no-img-element -- dynamic remote cover, no known dimensions (same convention as course detail page)
          <img
            alt=""
            className="absolute inset-0 h-full w-full object-cover"
            loading="lazy"
            src={course.cover_url}
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center bg-gradient-to-br from-primary/15 to-muted">
            <span aria-hidden className="text-5xl font-bold text-primary/40">
              {course.title.trim().charAt(0).toUpperCase() || <BookOpen className="h-10 w-10" />}
            </span>
          </div>
        )}
      </div>

      <div className="flex flex-1 flex-col gap-1.5 p-4">
        <div className="flex flex-wrap items-center gap-1.5 empty:hidden">
          {owned && course.status !== "published" && (
            <Badge className="capitalize" variant="outline">{course.status}</Badge>
          )}
        </div>
        <Link
          className="line-clamp-2 text-sm font-semibold leading-snug after:absolute after:inset-0 after:content-['']"
          href={href ?? (enrolled ? ROUTES.courseLearn(course.slug) : ROUTES.course(course.slug))}
        >
          {course.title}
        </Link>

        {(course.instructor_name || course.estimated_hours || showProgress || showPrice) && (
          <p className="flex items-center gap-1.5 text-xs text-muted-foreground">
            {course.instructor_name && <InstructorHover instructor={course.instructor} name={course.instructor_name} />}
            {course.instructor_name && course.estimated_hours && <span aria-hidden>·</span>}
            {course.estimated_hours && (
              <span className="flex shrink-0 items-center gap-1">
                <Clock aria-hidden className="h-3.5 w-3.5" />
                {course.estimated_hours}h
              </span>
            )}
            {showPrice && (
              <span className="ml-auto shrink-0 text-sm font-bold text-foreground">
                {course.is_free ? "Free" : formatMoney(course.price_cents, currency)}
              </span>
            )}
            {showProgress && <ProgressRing completed={progress?.completed} pct={progressPct} total={progress?.total} />}
          </p>
        )}

        {/* Spacer so footers align across the grid regardless of title length */}
        <div className="flex-1" />

        <div className="flex items-center gap-3 text-xs text-muted-foreground empty:hidden">
          {course.avg_rating !== null && (
            <span className="flex items-center gap-1">
              <Star aria-hidden className="h-3.5 w-3.5 fill-primary text-primary" />
              <span className="font-semibold text-foreground">{course.avg_rating.toFixed(1)}</span>
              <span aria-label={`${course.review_count} reviews`}>({course.review_count})</span>
            </span>
          )}
        </div>
      </div>

      {showProgress && (
        <div
          aria-label={`${progressPct}% complete`}
          aria-valuemax={100}
          aria-valuemin={0}
          aria-valuenow={progressPct}
          className="absolute inset-x-0 bottom-0 h-1.5 bg-muted"
          role="progressbar"
        >
          <div
            className="h-full bg-primary"
            style={{ "--progress": `${progressPct}%`, width: "var(--progress)" } as CSSProperties}
          />
        </div>
      )}
    </article>
  );
}
