import { getPlanningBoard } from "@/lib/server/gitlab-planning";

export async function PlanningSidebarUser() {
  const { user } = await getPlanningBoard();

  return (
    <div className="flex items-center gap-3">
      <div className="flex size-10 items-center justify-center rounded-xl bg-(--ae-brand) text-lg font-bold text-(--ae-card) shadow-sm">
        {user.initial}
      </div>
      <div className="leading-tight">
        <div className="text-sm font-bold text-(--ae-ink)">{user.name}</div>
        <div className="text-xs font-medium text-(--ae-faint)">{user.workspace}</div>
      </div>
    </div>
  );
}
