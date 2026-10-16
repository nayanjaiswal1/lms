import { Bell, Plus } from "lucide-react";

import { Button } from "@/components/ui/button";
interface DashboardHeaderProps {
  title: string;
  subtitle: string;
  initial: string;
}

export function DashboardHeader({ title, subtitle, initial }: DashboardHeaderProps) {
  return (
    <header className="safe-top sticky top-0 z-sticky flex h-14 items-center justify-between border-b border-border/80 bg-card/90 px-4 shadow-card backdrop-blur-sm lg:h-16 lg:bg-card/80 lg:px-7 lg:shadow-none">
      <div className="flex items-center gap-2.5 lg:hidden">
        <div className="flex size-8 shrink-0 items-center justify-center rounded-xl bg-primary text-sm font-bold text-(--ae-card) shadow-card">
          {initial}
        </div>
        <div className="leading-tight">
          <h1 className="flex items-center gap-1.5 text-sm font-bold tracking-tight text-foreground">
            <span>Auto Expand</span>
            <span className="rounded border border-(--ae-brand-200) bg-(--ae-brand-soft) px-1.5 py-0.5 text-xs font-semibold text-primary">Board</span>
          </h1>
          <p className="max-w-36 truncate text-xs font-medium text-muted-foreground">Organize &amp; delegate</p>
        </div>
      </div>

      <div className="hidden lg:block">
        <h1 className="page-title">{title}</h1>
        <p className="text-xs font-medium text-muted-foreground">{subtitle}</p>
      </div>

      <div className="flex items-center gap-1.5 lg:gap-4">
        <Button aria-label="Notifications"
          className="relative flex size-9 items-center justify-center rounded-xl text-muted-foreground transition-colors hover:bg-muted hover:text-foreground lg:size-auto lg:border lg:border-border lg:p-2 lg:hover:bg-accent"
          type="button"
          variant="unstyled"
        >
          <Bell aria-hidden className="size-5 lg:size-4" />
          <span className="absolute right-2 top-2 size-2 rounded-full border-2 border-(--ae-card) bg-(--ae-brand-500) lg:right-1.5 lg:top-1.5 lg:size-1.5 lg:border-0" />
        </Button>
        <Button aria-label="Add task"
          className="flex size-9 items-center justify-center gap-1.5 rounded-xl bg-primary text-xs font-semibold text-(--ae-card) shadow-card transition-colors hover:bg-(--ae-brand-hover) lg:size-auto lg:px-3.5 lg:py-1.5"
          type="button"
          variant="unstyled"
        >
          <Plus aria-hidden className="size-4" strokeWidth={2.5} />
          <span className="hidden lg:inline">Add Task</span>
        </Button>
      </div>
    </header>
  );
}
