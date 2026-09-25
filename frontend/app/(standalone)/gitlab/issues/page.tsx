import { IssueList } from "@/components/gitlab-planning/issue-list";
import { IssuesPagination } from "@/components/gitlab-planning/issues-pagination";
import { IssuesToolbar } from "@/components/gitlab-planning/issues-toolbar";
import { IssuesTopbar } from "@/components/gitlab-planning/issues-topbar";
import type { AeIssue } from "@/lib/server/gitlab-planning";
import { getPlanningIssues } from "@/lib/server/gitlab-planning";
import { requireAccess } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";

export const metadata = { title: "Issues & Tasks" };

interface IssuesPageProps {
  searchParams: Promise<{ state?: string; density?: string; bulk?: string }>;
}

const STATE_FILTER: Record<string, (i: AeIssue) => boolean> = {
  open: () => true,
  in_progress: (i) => i.status === "In Progress",
  done: (i) => i.status === "Done",
  all: () => true,
};

export default async function IssuesPage({ searchParams }: IssuesPageProps) {
  await requireAccess(FEATURES.GITLAB_INTEGRATION);
  const [page, params] = await Promise.all([getPlanningIssues(), searchParams]);
  const state = params.state && params.state in STATE_FILTER ? params.state : "open";
  const density = params.density === "normal" ? "normal" : "compact";
  const bulk = params.bulk !== "0";
  const issues = page.issues.filter(STATE_FILTER[state]);

  return (
    <div className="min-h-dvh bg-(--m-surface) text-foreground">
      <IssuesTopbar />
      <main className="mx-auto flex w-full max-w-400 flex-col gap-3 p-3 sm:p-4">
        <IssuesToolbar bulk={bulk} density={density} page={page} state={state} />
        <IssueList bulk={bulk} compact={density === "compact"} issues={issues} />
        <IssuesPagination pagination={page.pagination} shown={issues.length} />
      </main>
    </div>
  );
}
