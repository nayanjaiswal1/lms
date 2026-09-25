import { getPlanningBoard } from "@/lib/server/gitlab-planning";

export async function PlanningSidebarUser() {
  const { user } = await getPlanningBoard();

  return (
    <div className="flex items-center gap-3">
      <div className="flex size-10 items-center justify-center rounded-xl bg-primary text-lg font-bold text-(--ae-card) shadow-card">
        {user.initial}
      </div>
      <div className="leading-tight">
        <div className="text-sm font-bold text-foreground">{user.name}</div>
        <div className="text-xs font-medium text-muted-foreground">{user.workspace}</div>
      </div>
    </div>
  );
}
