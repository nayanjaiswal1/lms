import Link from "next/link";
import { notFound } from "next/navigation";
import { BookOpen, CheckCircle2, Library, Pencil } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { CourseProgressBar } from "@/components/courses/course-progress-bar";
import { BundleEnrollButton } from "@/components/bundles/bundle-enroll-button";
import { getBundleBySlug, getManagedBundleBySlug } from "@/lib/server/bundles";
import { getMyPermissions } from "@/lib/server/permissions";
import { getPaymentsCurrency } from "@/lib/server/payments";
import { formatMoney } from "@/lib/money";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ slug: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { slug } = await params;
  return { title: slug };
}

export default async function BundlePage({ params }: Props) {
  const { slug } = await params;
  const [permissions, currency] = await Promise.all([getMyPermissions(), getPaymentsCurrency()]);
  const canManage = permissions.includes(PERMISSIONS.COURSES.CREATE);
  // Draft bundles 404 on the student endpoint; instructors preview them
  // through the managed one instead.
  const bundle =
    (await getBundleBySlug(slug).catch(() => null)) ??
    (canManage ? await getManagedBundleBySlug(slug).catch(() => null) : null);
  if (!bundle) notFound();
  const allEnrolled = bundle.courses.length > 0 && bundle.courses.every((c) => c.is_enrolled);
  const anyEnrolled = bundle.courses.some((c) => c.is_enrolled);
  const paidCourseTitles = Object.fromEntries(bundle.courses.filter((c) => !c.is_free).map((c) => [c.id, c.title]));

  return (
    <main className="page-container">
      <Breadcrumb items={[{ label: "Courses", href: ROUTES.COURSES }, { label: bundle.title }]} />

      <div className="mb-8 flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <Library aria-hidden className="h-4 w-4" />
            <span>Bundle · {bundle.courses.length} course{bundle.courses.length === 1 ? "" : "s"}</span>
          </div>
          <h1 className="section-title mt-1">
            {bundle.title}
            {bundle.status === "draft" && <Badge className="ml-3 align-middle" variant="outline">Draft</Badge>}
          </h1>
          {bundle.description && <p className="mt-3 max-w-2xl text-muted-foreground">{bundle.description}</p>}
          <div className="mt-4 flex flex-wrap gap-3">
            {!allEnrolled && bundle.courses.length > 0 && (
              <BundleEnrollButton bundleID={bundle.id} paidCourseTitles={paidCourseTitles} slug={bundle.slug} />
            )}
            {canManage && (
              <Button asChild className="touch-target" variant="outline">
                <Link href={ROUTES.bundleEdit(bundle.slug)}>
                  <Pencil aria-hidden className="mr-2 h-4 w-4" />
                  Edit bundle
                </Link>
              </Button>
            )}
          </div>
        </div>
        {anyEnrolled && (
          <CourseProgressBar
            className="card-base shrink-0 p-6"
            completed={bundle.progress.completed}
            label="Bundle progress"
            total={bundle.progress.total}
          />
        )}
      </div>

      {bundle.courses.length === 0 ? (
        <div className="card-base empty-state">
          <BookOpen aria-hidden className="empty-state-icon" />
          <p>No courses in this bundle yet.</p>
        </div>
      ) : (
        <ol className="flex flex-col gap-3">
          {bundle.courses.map((course, i) => {
            const done = course.is_enrolled && course.progress.total > 0 && course.progress.completed === course.progress.total;
            return (
              <li className="card-interactive relative flex items-center gap-4 p-4" key={course.id}>
                <span
                  aria-hidden
                  className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-muted text-sm font-semibold"
                >
                  {done ? <CheckCircle2 className="h-5 w-5 text-success" /> : i + 1}
                </span>
                <div className="min-w-0 flex-1">
                  <Link
                    className="line-clamp-1 font-semibold after:absolute after:inset-0 after:content-['']"
                    href={ROUTES.course(course.slug)}
                  >
                    {course.title}
                  </Link>
                  <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                    <span className="capitalize">{course.difficulty}</span>
                    {course.estimated_hours !== null && <span>· {course.estimated_hours}h</span>}
                    {course.is_enrolled && course.progress.total > 0 && (
                      <span>· {Math.round(course.progress.pct)}% complete</span>
                    )}
                  </div>
                </div>
                {course.is_enrolled ? (
                  <Badge variant="secondary">Enrolled</Badge>
                ) : course.is_free ? (
                  <Badge variant="secondary">Free</Badge>
                ) : (
                  <Badge variant="outline">{formatMoney(course.price_cents, currency)}</Badge>
                )}
              </li>
            );
          })}
        </ol>
      )}
    </main>
  );
}
