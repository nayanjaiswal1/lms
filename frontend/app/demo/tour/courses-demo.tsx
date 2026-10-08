import Link from "next/link";
import { FileText, FlaskConical, HelpCircle, PlayCircle, type LucideIcon } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import ROUTES from "@/lib/routes";
import { getPublicCourses, getPublicCourseTree } from "@/lib/server/courses";
import { cn } from "@/lib/utils";

interface CoursesDemoProps {
  slug?: string;
}

const COURSE_LIMIT = 8;

const TYPE_ICONS: Record<string, LucideIcon> = {
  video: PlayCircle,
  lab: FlaskConical,
  assessment: HelpCircle,
};

function tabHref(slug: string): string {
  return `${ROUTES.DEMO_TOUR}?tab=courses&course=${slug}`;
}

// Real catalog + real course outline, fetched from the backend's anonymous
// /api/public endpoints. Lessons open in the real anonymous learning flow.
export async function CoursesDemo({ slug }: CoursesDemoProps) {
  const { courses } = await getPublicCourses(COURSE_LIMIT);

  if (courses.length === 0) {
    return (
      <div className="empty-state">
        <p>No public courses are available right now.</p>
      </div>
    );
  }

  const active = courses.find((c) => c.slug === slug) ?? courses[0];
  const tree = await getPublicCourseTree(active.slug);
  const lessonCount = tree?.sections.reduce((n, s) => n + s.modules.length, 0) ?? 0;

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1>Courses</h1>
        <p className="text-muted-foreground">Live from the MindForge catalog — open any lesson to learn it for real.</p>
      </div>

      <div className="grid gap-4 lg:grid-cols-[18rem_1fr]">
        <nav aria-label="Public courses" className="card-base flex flex-col gap-1 p-3">
          {courses.map((c) => (
            <Link
              aria-current={c.slug === active.slug ? "true" : undefined}
              className={cn(
                "rounded-md px-3 py-2 text-sm no-underline hover:no-underline",
                c.slug === active.slug ? "bg-primary/10 text-primary" : "text-muted-foreground hover:text-foreground",
              )}
              href={tabHref(c.slug)}
              key={c.id}
            >
              <span className="line-clamp-2">{c.title}</span>
            </Link>
          ))}
        </nav>

        <article className="card-base flex min-w-0 flex-col gap-4 p-6">
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="subsection-title">{active.title}</h2>
            <Badge variant="secondary">{active.difficulty}</Badge>
          </div>
          {active.description && (
            <p className="line-clamp-3 text-sm text-muted-foreground">{active.description}</p>
          )}
          <p className="text-xs text-muted-foreground">
            By {active.instructor_name} · {tree?.sections.length ?? 0} sections · {lessonCount} lessons
          </p>

          {tree?.sections.map((section) => (
            <section key={section.id}>
              <h3 className="mb-2 text-sm font-semibold">{section.title}</h3>
              <ul className="flex flex-col gap-1">
                {section.modules.map((m) => {
                  const Icon = TYPE_ICONS[m.type] ?? FileText;
                  return (
                    <li key={m.id}>
                      <Link
                        className="flex min-w-0 items-center gap-3 rounded-md px-3 py-2 text-sm text-muted-foreground no-underline hover:bg-muted hover:text-foreground hover:no-underline"
                        href={ROUTES.courseLearnModule(active.slug, m.id)}
                      >
                        <Icon aria-hidden className="h-4 w-4 shrink-0" />
                        <span className="min-w-0 flex-1 truncate">{m.title}</span>
                      </Link>
                    </li>
                  );
                })}
              </ul>
            </section>
          ))}

          <Button asChild className="self-start" size="sm">
            <Link href={ROUTES.courseLearn(active.slug)}>Start learning</Link>
          </Button>
        </article>
      </div>
    </div>
  );
}
