import Link from "next/link";
import { LayoutGrid } from "lucide-react";
import { AiAssistantCard } from "@/components/gitlab-planning/ai-assistant-card";
import { ChangeLogCard } from "@/components/gitlab-planning/change-log-card";
import { DashboardHeader } from "@/components/gitlab-planning/dashboard-header";
import { EisenhowerMatrix } from "@/components/gitlab-planning/eisenhower-matrix";
import { QuickNotesCard } from "@/components/gitlab-planning/quick-notes-card";
import { TaskDetailPanel } from "@/components/gitlab-planning/task-detail-panel";
import { getPlanningBoard } from "@/lib/server/gitlab-planning";
import ROUTES from "@/lib/routes";
import { cn } from "@/lib/utils";
import { requireAccess } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";

export const metadata = { title: "Planning Board" };

interface PlanningPageProps {
  searchParams: Promise<{ view?: string; tab?: string }>;
}

export default async function PlanningPage({ searchParams }: PlanningPageProps) {
  await requireAccess(FEATURES.GITLAB_INTEGRATION);
  const [board, params] = await Promise.all([getPlanningBoard(), searchParams]);
  // Mobile shows one pane at a time (Matrix | Active Task); xl shows both.
  const showTask = params.view === "task";
  const tab = Math.max(0, Math.min(board.task.tabs.length - 1, Number(params.tab) || 0));
  const taskCount = board.quadrants.reduce((n, q) => n + q.tasks.length, 0);

  const segment = (active: boolean) =>
    cn(
      "flex flex-1 items-center justify-center gap-1.5 rounded-lg py-1.5 text-xs transition-all",
      active ? "bg-card font-bold text-primary shadow-card" : "font-semibold text-muted-foreground hover:text-foreground",
    );

  return (
    <>
      <DashboardHeader initial={board.user.initial} subtitle={board.subtitle} title={board.title} />

      <main className="mx-auto flex w-full max-w-md flex-col gap-4 px-3.5 py-4 sm:max-w-none sm:gap-6 sm:p-6 xl:grid xl:grid-cols-12 xl:items-start">
        <nav aria-label="Board view" className="order-first flex items-center rounded-xl bg-muted p-1 shadow-card xl:hidden">
          <Link aria-current={!showTask ? "page" : undefined} className={segment(!showTask)} href={ROUTES.GITLAB_PLANNING} scroll={false}>
            <LayoutGrid aria-hidden className="size-3.5" />
            <span>Matrix ({taskCount})</span>
          </Link>
          <Link aria-current={showTask ? "page" : undefined} className={segment(showTask)} href={`${ROUTES.GITLAB_PLANNING}?view=task`} scroll={false}>
            <span className="size-2 rounded-full bg-(--t-dot)" data-tone={board.task.dot} />
            <span>Active Task ({board.task.steps.length})</span>
          </Link>
        </nav>

        {/* Below xl the left column dissolves (`contents`) so the task panel
            can slot between the matrix and the assistant, as in the Stitch
            mobile layout. "Active Task" view hides everything but the task. */}
        <div className={cn("xl:col-span-7 xl:block xl:space-y-6", showTask ? "hidden" : "contents")}>
          <EisenhowerMatrix quadrants={board.quadrants} selectedTaskId={board.task.id} />
          <div className="order-3 xl:order-none">
            <AiAssistantCard placeholder={board.ai_placeholder} suggestions={board.ai_suggestions} />
          </div>
          <div className="order-4 grid grid-cols-1 gap-4 sm:grid-cols-2 xl:order-none">
            <ChangeLogCard entries={board.change_log} />
            <QuickNotesCard />
          </div>
        </div>

        <TaskDetailPanel
          activeTab={tab}
          changeLog={board.change_log}
          className="order-2 xl:order-none xl:col-span-5"
          task={board.task}
        />
      </main>
    </>
  );
}
