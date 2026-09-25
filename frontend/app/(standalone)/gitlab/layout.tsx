// GitLab planning & tasks (Auto Expand Board) — carries its own Stitch
// identity (Inter, slate/blue + Material issues palette) scoped under .ae in
// planning.css, with its own sidebar (lg+) and bottom nav (<lg).

import { Inter } from "next/font/google";
import { PlanningSidebar } from "@/components/gitlab-planning/planning-sidebar";
import { PlanningBottomNav } from "@/components/gitlab-planning/planning-bottom-nav";
import { getPlanningBoard } from "@/lib/server/gitlab-planning";
import { cn } from "@/lib/utils";
import "@/components/gitlab-planning/planning.css";

const inter = Inter({ subsets: ["latin"], variable: "--font-ae-sans" });

export default async function GitLabPlanningLayout({ children }: { children: React.ReactNode }) {
  const { user } = await getPlanningBoard();

  return (
    <div className={cn(inter.variable, "ae flex min-h-dvh")}>
      <PlanningSidebar name={user.name} initial={user.initial} workspace={user.workspace} />
      <div className="flex min-w-0 flex-1 flex-col pb-20 lg:pb-0">{children}</div>
      <PlanningBottomNav />
    </div>
  );
}
