import type { Metadata } from "next";
import { LayoutGrid } from "lucide-react";

import { requireAccess } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import { getBoard } from "@/lib/projects/server";
import { BoardList } from "@/components/projects/board-list";

export const metadata: Metadata = {
  title: "Project Board",
  description: "Browse open project requirements and apply to join a team.",
};

export default async function ProjectBoardPage() {
  await requireAccess(FEATURES.GITLAB_INTEGRATION);
  const rows = await getBoard();

  return (
    <main className="page-container">
      <header className="page-header">
        <div className="flex flex-col gap-1">
          <h1 className="page-title">Project board</h1>
          <p className="text-muted-foreground">
            {rows.length} open requirement{rows.length === 1 ? "" : "s"} accepting applications
          </p>
        </div>
      </header>

      {rows.length === 0 ? (
        <div className="empty-state mt-10">
          <LayoutGrid aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="mt-3 font-medium">Nothing open right now</p>
          <p className="text-sm text-muted-foreground">Check back once a new project is posted.</p>
        </div>
      ) : (
        <div className="mt-8">
          <BoardList rows={rows} />
        </div>
      )}
    </main>
  );
}
