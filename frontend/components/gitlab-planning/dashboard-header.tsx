import { Bell, Plus, Search } from "lucide-react";

interface DashboardHeaderProps {
  title: string;
  subtitle: string;
  initial: string;
}

export function DashboardHeader({ title, subtitle, initial }: DashboardHeaderProps) {
  return (
    <header className="safe-top sticky top-0 z-sticky flex h-14 items-center justify-between border-b border-(--ae-line)/80 bg-(--ae-card)/90 px-4 shadow-2xs backdrop-blur-sm lg:h-16 lg:bg-(--ae-card)/80 lg:px-7 lg:shadow-none">
      {/* Mobile brand */}
      <div className="flex items-center gap-2.5 lg:hidden">
        <div className="flex size-8 shrink-0 items-center justify-center rounded-xl bg-(--ae-brand) text-sm font-bold text-(--ae-card) shadow-sm">
          {initial}
        </div>
        <div className="leading-tight">
          <h1 className="flex items-center gap-1.5 text-sm font-bold tracking-tight text-(--ae-ink)">
            <span>Auto Expand</span>
            <span className="rounded border border-(--ae-brand-200) bg-(--ae-brand-soft) px-1.5 py-0.5 text-[10px] font-semibold text-(--ae-brand-hover)">Board</span>
          </h1>
          <p className="max-w-36 truncate text-[10px] font-medium text-(--ae-faint)">Organize &amp; delegate</p>
        </div>
      </div>

      {/* Desktop title */}
      <div className="hidden lg:block">
        <h1 className="text-lg font-bold tracking-tight text-(--ae-ink)">{title}</h1>
        <p className="text-xs font-medium text-(--ae-faint)">{subtitle}</p>
      </div>

      <div className="flex items-center gap-1.5 lg:gap-4">
        <label className="relative hidden w-80 lg:block">
          <span className="sr-only">Search</span>
          <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-(--ae-faint)" aria-hidden />
          <input
            type="search"
            placeholder="Search tasks, steps, logs..."
            className="w-full rounded-xl border border-(--ae-line) bg-(--ae-hover)/70 py-1.5 pl-9 pr-4 text-xs text-(--ae-text) transition-all placeholder:text-(--ae-faint) focus:border-(--ae-brand-500) focus:bg-(--ae-card) focus:outline-none focus:ring-2 focus:ring-(--ae-brand-500)/20"
          />
        </label>
        <button type="button" aria-label="Search" className="flex size-9 items-center justify-center rounded-xl text-(--ae-muted) transition-colors hover:bg-(--ae-soft) hover:text-(--ae-text) lg:hidden">
          <Search className="size-5" aria-hidden />
        </button>
        <button
          type="button"
          aria-label="Notifications"
          className="relative flex size-9 items-center justify-center rounded-xl text-(--ae-muted) transition-colors hover:bg-(--ae-soft) hover:text-(--ae-body) lg:size-auto lg:border lg:border-(--ae-line) lg:p-2 lg:hover:bg-(--ae-hover)"
        >
          <Bell className="size-5 lg:size-4" aria-hidden />
          <span className="absolute right-2 top-2 size-2 rounded-full border-2 border-(--ae-card) bg-(--ae-brand-500) lg:right-1.5 lg:top-1.5 lg:size-1.5 lg:border-0" />
        </button>
        <button
          type="button"
          aria-label="Add task"
          className="flex size-9 items-center justify-center gap-1.5 rounded-xl bg-(--ae-brand) text-xs font-semibold text-(--ae-card) shadow-sm transition-colors hover:bg-(--ae-brand-hover) lg:size-auto lg:px-3.5 lg:py-1.5"
        >
          <Plus className="size-4" strokeWidth={2.5} aria-hidden />
          <span className="hidden lg:inline">Add Task</span>
        </button>
      </div>
    </header>
  );
}
