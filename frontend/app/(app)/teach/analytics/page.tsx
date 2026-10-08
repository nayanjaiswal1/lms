import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { EnrollmentTrendChart } from "@/components/courses/analytics/enrollment-trend-chart";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { LoadMoreButton } from "@/components/shared/load-more-button";
import { Badge } from "@/components/ui/badge";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import {
  ANALYTICS_DEFAULT_DAYS,
  ANALYTICS_MAX_LIMIT,
  ANALYTICS_PAGE_STEP,
  ORG_COURSES_DEFAULT_LIMIT,
} from "@/lib/constants";
import { FEATURES } from "@/lib/features";
import ROUTES from "@/lib/routes";
import { getOrgCourseSummaries, getOrgEnrollmentTrend } from "@/lib/server/course-analytics";
import { requireAccess } from "@/lib/server/features";
import { getMyPermissions } from "@/lib/server/permissions";

export const metadata: Metadata = { title: "Course analytics" };

interface Props {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}

export default async function TeachAnalyticsPage({ searchParams }: Props) {
  await requireAccess(FEATURES.COURSES);
  const [sp, myPerms] = await Promise.all([searchParams, getMyPermissions()]);
  if (!myPerms.includes(PERMISSIONS.COURSES.VIEW_ANALYTICS)) notFound();

  const raw = Number.parseInt(Array.isArray(sp.limit) ? sp.limit[0] : (sp.limit ?? ""), 10);
  const limit = Number.isFinite(raw) && raw > 0 ? Math.min(raw, ANALYTICS_MAX_LIMIT) : ORG_COURSES_DEFAULT_LIMIT;

  const [points, summaries] = await Promise.all([
    getOrgEnrollmentTrend(ANALYTICS_DEFAULT_DAYS),
    getOrgCourseSummaries(limit),
  ]);

  return (
    <main className="page-container">
      <Breadcrumb items={[{ label: "Teach", href: ROUTES.TEACH }, { label: "Analytics" }]} />

      <div className="page-header">
        <h1 className="page-title">Course analytics</h1>
      </div>

      <section aria-labelledby="org-trend-heading" className="card-base mb-8 p-6">
        <h2 className="section-title mb-4" id="org-trend-heading">Enrollments, last {ANALYTICS_DEFAULT_DAYS} days</h2>
        <EnrollmentTrendChart points={points} />
      </section>

      <section aria-labelledby="org-courses-heading" className="card-base p-6">
        <h2 className="section-title mb-4" id="org-courses-heading">Courses</h2>
        {summaries.courses.length === 0 ? (
          <div className="empty-state py-10">
            <p className="text-sm text-muted-foreground">No courses to report on yet.</p>
          </div>
        ) : (
          <>
            <ResponsiveTable>
              <table className="w-full text-sm">
                <thead>
                  <tr className="whitespace-nowrap border-b border-border text-left text-xs text-muted-foreground">
                    <th className="pb-2 font-medium">Course</th>
                    <th className="pb-2 font-medium">Status</th>
                    <th className="pb-2 font-medium">Enrolled</th>
                    <th className="pb-2 font-medium">Completed</th>
                    <th className="pb-2 font-medium">Avg progress</th>
                    <th className="pb-2 font-medium">Active (7d)</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {summaries.courses.map((c) => (
                    <tr className="whitespace-nowrap" key={c.course_id}>
                      <td className="max-w-xs py-3 pr-4">
                        <Link className="block truncate font-medium hover:underline" href={ROUTES.courseEditAnalytics(c.slug)}>
                          {c.title}
                        </Link>
                      </td>
                      <td className="py-3 pr-4"><Badge variant="secondary">{c.status}</Badge></td>
                      <td className="py-3 pr-4">{c.enrolled}</td>
                      <td className="py-3 pr-4">{c.completed}</td>
                      <td className="py-3 pr-4 text-primary">{Math.round(c.avg_progress_pct)}%</td>
                      <td className="py-3">{c.active_last_7d}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </ResponsiveTable>
            <LoadMoreButton
              defaultLimit={ORG_COURSES_DEFAULT_LIMIT}
              hasMore={summaries.courses.length < summaries.total}
              max={ANALYTICS_MAX_LIMIT}
              step={ANALYTICS_PAGE_STEP}
            />
          </>
        )}
      </section>
    </main>
  );
}
