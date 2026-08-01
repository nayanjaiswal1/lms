import Link from "next/link"
import { Badge } from "@/components/ui/badge"
import ROUTES from "@/lib/routes"

interface LabUsageRow {
  lab_id: string
  lab_title: string
  image: string
  sessions: number
  container_seconds: number
}

interface CourseLabUsageRow {
  course_id: string
  course_title: string
  sessions: number
  student_count: number
  container_seconds: number
}

interface StudentLabUsageRow {
  user_id: string
  name: string
  email: string
  sessions: number
  container_seconds: number
}

interface OrgLabUsage {
  total_container_seconds: number
  total_sessions: number
  by_lab: LabUsageRow[]
}

export interface LabUsageResponse {
  window_days: number
  org: OrgLabUsage
  by_course: CourseLabUsageRow[]
  by_student: StudentLabUsageRow[]
}

// Compute cost is billed in seconds (lab_usage_events.quantity), but nobody
// reading this page thinks in seconds — h/m matches how the rest of the app
// already shows lab duration (e.g. the in-session timer).
function formatHoursMinutes(totalSeconds: number): string {
  const totalMinutes = Math.round(totalSeconds / 60)
  const hours = Math.floor(totalMinutes / 60)
  const minutes = totalMinutes % 60
  if (hours === 0) return `${minutes}m`
  if (minutes === 0) return `${hours}h`
  return `${hours}h ${minutes}m`
}

function WindowSwitcher({ days, options }: { days: number; options: readonly number[] }) {
  return (
    <div className="flex items-center gap-1 rounded-md border border-border p-1">
      {options.map((opt) => (
        <Link
          className={`px-3 py-1.5 text-sm rounded-sm transition-colors duration-fast ${
            opt === days
              ? "bg-primary text-primary-foreground font-medium"
              : "text-muted-foreground hover:text-foreground"
          }`}
          href={`${ROUTES.ADMIN_LABS_USAGE}?days=${opt}`}
          key={opt}
        >
          {opt}d
        </Link>
      ))}
    </div>
  )
}

export function LabUsageView({
  days,
  windowOptions,
  usage,
}: {
  days: number
  windowOptions: readonly number[]
  usage: LabUsageResponse
}) {
  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-title">Lab Compute Usage</h1>
          <p className="text-muted-foreground mt-1 max-w-2xl">
            Container time billed to your org over the last {usage.window_days} days — paused
            sessions don&apos;t count, since idle-pause stops CPU billing.
          </p>
          <Link
            className="text-sm text-primary underline underline-offset-2 mt-2 inline-block"
            href={ROUTES.ADMIN_LABS_WARM_POOLS}
          >
            View warm pool sizing →
          </Link>
        </div>
        <WindowSwitcher days={days} options={windowOptions} />
      </div>

      <div className="grid-stats mt-8">
        <div className="card-base p-6">
          <p className="text-sm text-muted-foreground">Total compute</p>
          <p className="text-3xl font-bold tracking-tight mt-1 tabular-nums">
            {formatHoursMinutes(usage.org.total_container_seconds)}
          </p>
        </div>
        <div className="card-base p-6">
          <p className="text-sm text-muted-foreground">Sessions</p>
          <p className="text-3xl font-bold tracking-tight mt-1 tabular-nums">
            {usage.org.total_sessions}
          </p>
        </div>
      </div>

      <section className="mt-10">
        <h2 className="section-title">By lab</h2>
        <div className="mt-4 card-base table-responsive">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-muted-foreground whitespace-nowrap">
                <th className="p-4 font-medium">Lab</th>
                <th className="p-4 font-medium">Image</th>
                <th className="p-4 font-medium text-right">Sessions</th>
                <th className="p-4 font-medium text-right">Compute</th>
              </tr>
            </thead>
            <tbody>
              {usage.org.by_lab.map((row) => (
                <tr className="border-b border-border last:border-0 whitespace-nowrap" key={row.lab_id}>
                  <td className="p-4 min-w-0 max-w-64 truncate font-medium text-foreground">{row.lab_title}</td>
                  <td className="p-4 min-w-0 max-w-48 truncate text-muted-foreground">
                    <code className="text-xs">{row.image}</code>
                  </td>
                  <td className="p-4 text-right tabular-nums">{row.sessions}</td>
                  <td className="p-4 text-right tabular-nums font-semibold text-primary">
                    {formatHoursMinutes(row.container_seconds)}
                  </td>
                </tr>
              ))}
              {usage.org.by_lab.length === 0 && (
                <tr>
                  <td className="p-8 text-center text-muted-foreground" colSpan={4}>
                    No lab sessions in this window.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section className="mt-10">
        <h2 className="section-title">By course</h2>
        <div className="mt-4 card-base table-responsive">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-muted-foreground whitespace-nowrap">
                <th className="p-4 font-medium">Course</th>
                <th className="p-4 font-medium text-right">Students</th>
                <th className="p-4 font-medium text-right">Sessions</th>
                <th className="p-4 font-medium text-right">Compute</th>
              </tr>
            </thead>
            <tbody>
              {usage.by_course.map((row) => (
                <tr className="border-b border-border last:border-0 whitespace-nowrap" key={row.course_id}>
                  <td className="p-4 min-w-0 max-w-64 truncate font-medium text-foreground">{row.course_title}</td>
                  <td className="p-4 text-right tabular-nums">{row.student_count}</td>
                  <td className="p-4 text-right tabular-nums">{row.sessions}</td>
                  <td className="p-4 text-right tabular-nums font-semibold text-primary">
                    {formatHoursMinutes(row.container_seconds)}
                  </td>
                </tr>
              ))}
              {usage.by_course.length === 0 && (
                <tr>
                  <td className="p-8 text-center text-muted-foreground" colSpan={4}>
                    No course-linked lab sessions in this window — standalone labs aren&apos;t
                    attributed to a course.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section className="mt-10">
        <div className="flex items-center justify-between gap-4 flex-wrap">
          <h2 className="section-title">By student</h2>
          <Badge className="badge-muted" variant="outline">Top {usage.by_student.length}</Badge>
        </div>
        <div className="mt-4 card-base table-responsive">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-muted-foreground whitespace-nowrap">
                <th className="p-4 font-medium">Student</th>
                <th className="p-4 font-medium text-right">Sessions</th>
                <th className="p-4 font-medium text-right">Compute</th>
              </tr>
            </thead>
            <tbody>
              {usage.by_student.map((row) => (
                <tr className="border-b border-border last:border-0 whitespace-nowrap" key={row.user_id}>
                  <td className="p-4 min-w-0 max-w-64">
                    <div className="font-medium text-foreground truncate">{row.name}</div>
                    <div className="text-xs text-muted-foreground truncate">{row.email}</div>
                  </td>
                  <td className="p-4 text-right tabular-nums">{row.sessions}</td>
                  <td className="p-4 text-right tabular-nums font-semibold text-primary">
                    {formatHoursMinutes(row.container_seconds)}
                  </td>
                </tr>
              ))}
              {usage.by_student.length === 0 && (
                <tr>
                  <td className="p-8 text-center text-muted-foreground" colSpan={3}>
                    No student lab activity in this window.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  )
}
