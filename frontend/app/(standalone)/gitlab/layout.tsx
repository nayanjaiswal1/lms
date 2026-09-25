// GitLab planning & tasks (Auto Expand Board) — carries its own Stitch
// identity (Inter, slate/blue + Material issues palette) scoped under .ae in
// planning.css, with its own sidebar (lg+) and bottom nav (<lg).
// The shell renders synchronously (sidebar user streams in) so this route's
// own loading.tsx shows inside it instead of the app-wide fallback. The
// access guard lives in each page.tsx.

import { Suspense } from "react";
import { Inter } from "next/font/google";
import { PlanningBottomNav } from "@/components/gitlab-planning/planning-bottom-nav";
import { PlanningSidebar } from "@/components/gitlab-planning/planning-sidebar";
import { PlanningSidebarUser } from "@/components/gitlab-planning/planning-sidebar-user";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";
import "@/components/gitlab-planning/planning.css";

const inter = Inter({ subsets: ["latin"], variable: "--font-ae-sans" });

export default function GitLabPlanningLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className={cn(inter.variable, "ae flex min-h-dvh")}>
      <PlanningSidebar
        user={
          <Suspense fallback={<Skeleton className="h-10 w-full" />}>
            <PlanningSidebarUser />
          </Suspense>
        }
      />
      <div className="flex min-w-0 flex-1 flex-col pb-20 lg:pb-0">{children}</div>
      <PlanningBottomNav />
    </div>
  );
}
