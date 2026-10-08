import Link from "next/link";
import { Calendar, ClipboardCheck } from "lucide-react";

import ROUTES from "@/lib/routes";
import { getPublicCourses } from "@/lib/server/courses";
import {
  DEMO_LEVEL,
  DEMO_STANDING,
  DEMO_UPCOMING,
  DEMO_USER,
} from "@/app/demo/tour/mock-data";
import { cn } from "@/lib/utils";

// Mirrors app/(app)/dashboard: courses + upcoming in the main column,
// standing in the right rail.
const DASHBOARD_COURSE_LIMIT = 3;

export async function DashboardDemo() {
  const { courses } = await getPublicCourses(DASHBOARD_COURSE_LIMIT);
  const firstName = DEMO_USER.name.split(" ")[0];

  return (
    <div>
      <div className="mb-8 flex flex-col gap-2">
        <h1>Welcome back, {firstName}</h1>
        <p className="text-muted-foreground">Here&apos;s your learning overview.</p>
      </div>

      <div className="grid grid-cols-1 gap-8 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <section className="mb-8">
            <h2 className="section-title mb-4">Your courses</h2>
            <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
              {courses.map((c) => (
                <Link className="card-base card-interactive flex flex-col gap-3 p-5 no-underline hover:no-underline" href={ROUTES.courseLearn(c.slug)} key={c.id}>
                  <h3 className="line-clamp-2 text-base font-semibold">{c.title}</h3>
                  <p className="text-xs text-muted-foreground">{c.instructor_name} · {c.difficulty}</p>
                  <p className="line-clamp-3 text-xs text-muted-foreground">{c.description}</p>
                </Link>
              ))}
              {courses.length === 0 && <p className="text-sm text-muted-foreground">No public courses yet.</p>}
            </div>
          </section>

          <section>
            <h2 className="section-title mb-4">Upcoming</h2>
            <div className="flex flex-col gap-3">
              {DEMO_UPCOMING.map((item) => {
                const Icon = item.kind === "assessment" ? ClipboardCheck : Calendar;
                return (
                  <div className="card-base flex items-center gap-3 p-4" key={item.title}>
                    <Icon aria-hidden className="h-5 w-5 shrink-0 text-muted-foreground" />
                    <div className="min-w-0">
                      <p className="truncate text-sm font-medium">{item.title}</p>
                      <p className="text-xs text-muted-foreground">{item.when}</p>
                    </div>
                  </div>
                );
              })}
            </div>
          </section>
        </div>

        <aside className="flex flex-col gap-8 lg:col-span-1">
          <section className="card-base flex flex-col gap-4 p-5">
            <h2 className="subsection-title">Your standing</h2>
            <ol className="flex flex-col gap-2">
              {DEMO_STANDING.map((row) => (
                <li
                  className={cn("flex items-center gap-3 rounded-lg px-3 py-2 text-sm", "me" in row && "bg-primary/10 font-medium")}
                  key={row.rank}
                >
                  <span className="w-5 tabular-nums text-muted-foreground">{row.rank}</span>
                  <span className="min-w-0 flex-1 truncate">{row.name}</span>
                  <span className="tabular-nums text-muted-foreground">{row.xp} XP</span>
                </li>
              ))}
            </ol>
            <div>
              <p className="mb-1 text-xs text-muted-foreground">{DEMO_LEVEL.label}</p>
              <div className="progress-track">
                <div className="progress-fill" style={{ "--progress": `${DEMO_LEVEL.progressPct}%` } as React.CSSProperties} />
              </div>
            </div>
          </section>
        </aside>
      </div>
    </div>
  );
}
