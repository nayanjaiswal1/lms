"use client";

import { useQueryState } from "nuqs";
import { LayoutGrid, ListTodo } from "lucide-react";

import { cn } from "@/lib/utils";

const VIEWS = [
  { value: "timeline", label: "Timeline", icon: ListTodo },
  { value: "topics", label: "Topics", icon: LayoutGrid },
] as const;

export function JournalViewTabs() {
  const [view, setView] = useQueryState("view", { defaultValue: "timeline", shallow: false });

  return (
    <div className="inline-flex w-fit gap-1 rounded-md border border-border bg-muted/40 p-1">
      {VIEWS.map(({ value, label, icon: Icon }) => (
        <button
          aria-current={view === value ? "true" : undefined}
          className={cn(
            "touch-target flex items-center gap-1.5 rounded-sm px-3 text-sm font-medium transition-colors duration-fast",
            view === value ? "bg-background text-foreground shadow-raised" : "text-muted-foreground hover:text-foreground",
          )}
          key={value}
          type="button"
          onClick={() => void setView(value === "timeline" ? null : value)}
        >
          <Icon aria-hidden className="size-4" />
          {label}
        </button>
      ))}
    </div>
  );
}
