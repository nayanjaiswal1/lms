"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Home, Inbox, Users, GitBranch, ListChecks, FileText, Settings, KanbanSquare, List, BookCheck, Bug, CalendarDays, LayoutDashboard, Rocket, Package, Star, FolderGit2 } from "lucide-react";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";
import { useProjectRole } from "@/components/workspace/project-role-provider";

interface WorkspaceTabsProps {
  workspaceId: string;
  sprintsEnabled: boolean;
  hasCohort: boolean;
}

export function WorkspaceTabs({ workspaceId, sprintsEnabled, hasCohort }: WorkspaceTabsProps) {
  const pathname = usePathname();
  const { atLeast, isOwner } = useProjectRole();
  const base = ROUTES.workspace(workspaceId);

  const tabs = [
    { href: base, label: "Home", Icon: Home, exact: true, show: true },
    { href: ROUTES.workspaceDashboard(workspaceId), label: "Dashboard", Icon: LayoutDashboard, exact: false, show: true },
    { href: ROUTES.workspaceInterests(workspaceId), label: "Interests", Icon: Inbox, exact: false, show: atLeast("manager") },
    { href: ROUTES.workspaceMembers(workspaceId), label: "Members", Icon: Users, exact: false, show: true },
    { href: ROUTES.workspaceTracks(workspaceId), label: "Tracks", Icon: GitBranch, exact: false, show: true },
    { href: ROUTES.workspaceBoard(workspaceId), label: "Backlog board", Icon: KanbanSquare, exact: false, show: true },
    { href: ROUTES.workspaceList(workspaceId), label: "List", Icon: List, exact: false, show: true },
    // Phase 5 — Sprints only shows once the project has sprints turned on
    // (redirect-to-home is the page's own guard for a direct link visit).
    { href: ROUTES.workspaceSprints(workspaceId), label: "Sprints", Icon: Rocket, exact: false, show: sprintsEnabled },
    { href: ROUTES.workspaceReleases(workspaceId), label: "Releases", Icon: Package, exact: false, show: true },
    { href: ROUTES.workspaceOnboarding(workspaceId), label: "Onboarding", Icon: ListChecks, exact: false, show: true },
    { href: ROUTES.workspaceRequirement(workspaceId), label: "Requirement", Icon: FileText, exact: false, show: true },
    { href: ROUTES.workspaceBrief(workspaceId), label: "Brief", Icon: BookCheck, exact: false, show: true },
    { href: ROUTES.workspaceBugs(workspaceId), label: "Bugs", Icon: Bug, exact: false, show: true },
    { href: ROUTES.workspaceMeetings(workspaceId), label: "Meetings", Icon: CalendarDays, exact: false, show: true },
    { href: ROUTES.workspaceFeedback(workspaceId), label: "Feedback", Icon: Star, exact: false, show: true },
    { href: ROUTES.workspaceCheckpoints(workspaceId), label: "Checkpoints", Icon: FolderGit2, exact: false, show: hasCohort },
    { href: ROUTES.workspaceSettings(workspaceId), label: "Settings", Icon: Settings, exact: false, show: isOwner },
  ].filter((tab) => tab.show);

  return (
    <nav aria-label="Workspace sections" className="mb-6 flex gap-1 overflow-x-auto border-b border-border">
      {tabs.map(({ href, label, Icon, exact }) => {
        const isActive = exact ? pathname === href : pathname.startsWith(href);
        return (
          <Link
            aria-current={isActive ? "page" : undefined}
            className={cn(
              "flex items-center gap-1.5 whitespace-nowrap border-b-2 px-4 py-2.5 text-sm font-medium transition-colors duration-fast",
              isActive ? "border-primary text-primary" : "border-transparent text-muted-foreground hover:text-foreground",
            )}
            href={href}
            key={href}
          >
            <Icon aria-hidden className="h-4 w-4" />
            {label}
          </Link>
        );
      })}
    </nav>
  );
}
