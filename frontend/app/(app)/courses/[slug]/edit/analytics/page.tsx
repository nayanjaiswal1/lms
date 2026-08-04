import { notFound } from "next/navigation";
import { Users, TrendingUp } from "lucide-react";
import { getCourseTree, getAllStudentProgress, getInstructorCourseBySlug, type StudentProgressRow } from "@/lib/server/courses";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ slug: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { slug } = await params;
  const course = await getInstructorCourseBySlug(slug).catch(() => undefined);
  return { title: course ? `${course.title} Analytics` : "Analytics" };
}

export default async function CourseAnalyticsPage({ params }: Props) {
  const { slug } = await params;
  const course = await getInstructorCourseBySlug(slug).catch(() => undefined);
  if (!course) notFound();

  const [tree, rows] = await Promise.all([
    getCourseTree(course.id).catch(() => null),
    getAllStudentProgress(course.id).catch(() => [] as StudentProgressRow[]),
  ]);

  if (!tree) notFound();
  const totalStudents = rows.length;
  const completed = rows.filter((r) => r.completed_modules === r.total_modules && r.total_modules > 0).length;
  const completionPct = totalStudents > 0 ? Math.round((completed / totalStudents) * 100) : 0;

  return (
    <main className="page-container">
      <Breadcrumb
        items={[
          { label: "Teach", href: ROUTES.TEACH },
          { label: tree.title, href: ROUTES.courseEdit(slug) },
          { label: "Analytics" },
        ]}
      />

      <div className="page-header">
        <h1 className="section-title">{tree.title} — Analytics</h1>
      </div>

      <div className="grid-stats mb-8">
        <div className="card-base flex flex-col gap-1 p-5">
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <Users aria-hidden className="h-4 w-4" />
            Total students
          </div>
          <p className="text-2xl font-bold">{totalStudents}</p>
        </div>
        <div className="card-base flex flex-col gap-1 p-5">
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <TrendingUp aria-hidden className="h-4 w-4" />
            Completion rate
          </div>
          <p className="text-2xl font-bold text-primary">{completionPct}%</p>
        </div>
      </div>

      {rows.length === 0 ? (
        <div className="empty-state py-12">
          <p className="text-sm text-muted-foreground">No students have enrolled yet.</p>
        </div>
      ) : (
        <div className="table-responsive">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-xs text-muted-foreground">
                <th className="pb-2 font-medium">Student</th>
                <th className="pb-2 font-medium">Progress</th>
                <th className="pb-2 font-medium">Last active</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {rows.map((row) => {
                const pct = row.total_modules > 0 ? Math.round((row.completed_modules / row.total_modules) * 100) : 0;
                return (
                  <tr key={row.user_id}>
                    <td className="py-3 pr-4">
                      <div className="flex flex-col">
                        <span className="font-medium">{row.name}</span>
                        <span className="text-xs text-muted-foreground">{row.email}</span>
                      </div>
                    </td>
                    <td className="py-3 pr-4">
                      <div className="flex items-center gap-2">
                        <div className="progress-track w-24">
                            <div className="progress-fill" style={{ "--progress": `${pct}%` } as React.CSSProperties} />
                        </div>
                        <span className="text-xs text-muted-foreground">{row.completed_modules}/{row.total_modules}</span>
                      </div>
                    </td>
                    <td className="py-3 text-muted-foreground">
                      {row.last_active ? new Date(row.last_active).toLocaleDateString() : "—"}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </main>
  );
}
