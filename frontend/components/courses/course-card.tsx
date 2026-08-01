import Link from "next/link";
import type { CSSProperties } from "react";
import { BookOpen, Clock, Star } from "lucide-react";
import { Badge } from "@/components/ui/badge";
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
  href?: string;
}

// Async only to read the deployment's currency — getPaymentsCurrency is
// React-cached, so a grid of cards still resolves it once per render.
export async function CourseCard({ course, enrolled, owned, canEdit, canViewAnalytics, progressPct, href }: CourseCardProps) {
  const currency = await getPaymentsCurrency();
  const showProgress = enrolled && progressPct !== undefined;

  return (
    <article className="card-interactive relative flex flex-col overflow-hidden p-0">
      {owned && (
        <div className="absolute right-3 top-3 z-dropdown">
          <ManageCourseMenu
            canEdit={canEdit ?? false}
            canViewAnalytics={canViewAnalytics ?? false}
            courseSlug={course.slug}
            courseTitle={course.title}
            published={course.status === "published"}
          />
        </div>
      )}
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
          className="line-clamp-2 text-sm font-semibold leading-snug after:absolute after:inset-0 after:content-['']"
          href={href ?? (enrolled ? ROUTES.courseLearn(course.slug) : ROUTES.course(course.slug))}
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

          {owned ? (
            course.status !== "published" && (
              <Badge className="ml-auto" variant="secondary">
                {course.status}
              </Badge>
            )
          ) : (
            !enrolled && (
              <span className="ml-auto text-sm font-bold text-foreground">
                {course.is_free ? "Free" : formatMoney(course.price_cents, currency)}
              </span>
            )
          )}
        </div>
      </div>

      {showProgress && (
        <div
          aria-label={`${progressPct}% complete`}
          aria-valuemax={100}
          aria-valuemin={0}
          aria-valuenow={progressPct}
          className="absolute inset-x-0 bottom-0 h-0.5 bg-muted"
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
