"use client";

import { cn } from "@/lib/utils";
import type { QuestionSection } from "@/lib/assessments/types";

interface SectionTabsProps {
  sections: QuestionSection[];
  currentType: string;
  onJump: (startIndex: number) => void;
}

// Mobile/tablet equivalent of <SectionSidebar> — a horizontal scrollable tab
// row instead of a squished sidebar (never collapse a sidebar on mobile).
export function SectionTabs({ sections, currentType, onJump }: SectionTabsProps) {
  if (sections.length < 2) return null;

  return (
    <div aria-label="Question sections" className="mb-4 flex gap-2 overflow-x-auto pb-1 lg:hidden" role="tablist">
      {sections.map((s) => (
        <button
          aria-selected={s.type === currentType}
          className={cn(
            "touch-target shrink-0 whitespace-nowrap rounded-md border px-3 text-xs font-medium transition-colors duration-fast",
            s.type === currentType
              ? "border-primary bg-primary/10 text-primary"
              : "border-border text-muted-foreground",
          )}
          key={s.type}
          role="tab"
          type="button"
          onClick={() => onJump(s.startIndex)}
        >
          {s.label} · {s.answeredCount}/{s.count}
        </button>
      ))}
    </div>
  );
}
