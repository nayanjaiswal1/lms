import Link from "next/link";
import { ArrowLeft, ExternalLink } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ProblemSolver } from "@/components/courses/problem-solver";
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

  const displayTitle = title ?? prettify(problem);
  const leetcodeUrl = `https://leetcode.com/problems/${problem}/`;
  const backHref = moduleId ? ROUTES.courseLearnModule(slug, moduleId) : ROUTES.courseLearn(slug);

  return (
    <main className="page-container py-6">
      <div className="mb-4">
        <Link
          className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
          href={backHref}
        >
          <ArrowLeft aria-hidden className="h-4 w-4" />
          Back to lesson
        </Link>
      </div>

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
