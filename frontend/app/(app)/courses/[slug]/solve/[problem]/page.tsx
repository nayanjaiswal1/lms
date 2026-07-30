import { notFound } from "next/navigation";
import { ExternalLink } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ProblemSolver } from "@/components/courses/problem-solver";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { findCourseBySlug, getCourses, getEnrollments } from "@/lib/server/courses";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ slug: string; problem: string }>;
  searchParams: Promise<{ title?: string; module?: string }>;
}

function prettify(problemSlug: string): string {
  return problemSlug
    .split("-")
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}

export async function generateMetadata({ params, searchParams }: Props) {
  const [{ problem }, { title }] = await Promise.all([params, searchParams]);
  return { title: `${title ?? prettify(problem)} — MindForge` };
}

// LeetCode-style solve page for a problem linked from lesson content:
// problem panel on the left, editor + run on the right. The statement
// itself lives on LeetCode — this page hosts the coding, not the prose.
export default async function ProblemSolvePage({ params, searchParams }: Props) {
  const [{ slug, problem }, { title, module: moduleId }] = await Promise.all([params, searchParams]);

  const [courses, enrollments] = await Promise.all([getCourses(), getEnrollments()]);
  const course = findCourseBySlug(courses, enrollments, slug);
  if (!course) notFound();

  const displayTitle = title ?? prettify(problem);
  const leetcodeUrl = `https://leetcode.com/problems/${problem}/`;
  const backHref = moduleId ? ROUTES.courseLearnModule(slug, moduleId) : ROUTES.courseLearn(slug);

  return (
    <main className="page-container">
      <Breadcrumb
        items={[
          { label: "Courses", href: ROUTES.COURSES },
          { label: course.title, href: ROUTES.course(slug) },
          { label: "Lesson", href: backHref },
          { label: displayTitle },
        ]}
      />

      <div className="stack-lg items-start">
        <section className="card-base flex w-full flex-col gap-4 p-6 lg:w-80 lg:shrink-0">
          <div className="flex flex-col gap-2">
            <Badge className="w-fit" variant="secondary">DSA Practice</Badge>
            <h1 className="text-xl font-semibold tracking-tight">{displayTitle}</h1>
          </div>
          <p className="text-sm text-muted-foreground">
            Read the problem statement on LeetCode, then write and run your solution here.
            Runs execute your code as-is and show stdout/stderr — bring your own test prints.
          </p>
          <Button asChild variant="outline">
            <a href={leetcodeUrl} rel="noopener noreferrer" target="_blank">
              Problem statement on LeetCode
              <ExternalLink aria-hidden className="h-4 w-4" />
            </a>
          </Button>
        </section>

        <section className="w-full min-w-0 flex-1">
          <ProblemSolver title={displayTitle} url={leetcodeUrl} />
        </section>
      </div>
    </main>
  );
}
