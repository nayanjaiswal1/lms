"use client";

import * as React from "react";
import { PanelLeftClose, PanelLeftOpen, ListChecks, Code2, PenLine, type LucideIcon } from "lucide-react";

import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import type { QuestionSection, StudentQuestion } from "@/lib/assessments/types";

// Icon per question type for the collapsed glimpse rail — tied to the closed
// StudentQuestion union, not a server-configurable option list.
const SECTION_ICONS: Record<StudentQuestion["type"], LucideIcon> = {
  mcq: ListChecks,
  coding: Code2,
  subjective: PenLine,
};

interface SectionSidebarProps {
  sections: QuestionSection[];
  currentType: string;
  onJump: (startIndex: number) => void;
}

// Desktop-only left nav for jumping between question-type sections (MCQ,
// Coding, Subjective). Hidden on mobile per the sidebar rule — a mobile
// equivalent lives in <SectionTabs>. Collapsible to a slim icon-only glimpse
// rail so it doesn't compete with the right question palette for width.
export function SectionSidebar({ sections, currentType, onJump }: SectionSidebarProps) {
  const [collapsed, setCollapsed] = React.useState(false);

  if (sections.length < 2) return null;

  if (collapsed) {
    return (
      <aside className="hidden lg:flex w-10 shrink-0 flex-col items-center gap-1.5 border-r border-border bg-card/50 py-3">
        <Button
          variant="ghost"
          size="icon"
          aria-label="Show section navigator"
          className="touch-target h-8 w-8"
          onClick={() => setCollapsed(false)}
        >
          <PanelLeftOpen aria-hidden className="h-4 w-4" />
        </Button>
        <div className="mt-1 flex flex-col gap-1.5 border-t border-border pt-2">
          {sections.map((s) => {
            const Icon = SECTION_ICONS[s.type];
            const isCurrent = s.type === currentType;
            return (
              <Button
                key={s.type}
                type="button"
                variant="ghost"
                size="icon"
                onClick={() => onJump(s.startIndex)}
                aria-current={isCurrent ? "true" : undefined}
                aria-label={`Jump to ${s.label} section, ${s.answeredCount} of ${s.count} answered`}
                className={cn("touch-target h-8 w-8", isCurrent && "bg-primary/10 text-primary")}
              >
                <Icon aria-hidden className="h-4 w-4" />
              </Button>
            );
          })}
        </div>
      </aside>
    );
  }

  return (
    <aside className="hidden lg:flex w-44 shrink-0 flex-col gap-1 overflow-y-auto border-r border-border bg-card/50 p-3">
      <div className="mb-1 flex items-center justify-between px-1">
        <span className="text-xs font-medium text-muted-foreground">Sections</span>
        <Button
          variant="ghost"
          size="icon"
          aria-label="Hide section navigator"
          className="touch-target h-6 w-6"
          onClick={() => setCollapsed(true)}
        >
          <PanelLeftClose aria-hidden className="h-3.5 w-3.5" />
        </Button>
      </div>
      {sections.map((s) => {
        const Icon = SECTION_ICONS[s.type];
        return (
          <Button
            key={s.type}
            type="button"
            variant="ghost"
            size="sm"
            onClick={() => onJump(s.startIndex)}
            aria-current={s.type === currentType ? "true" : undefined}
            className={cn("justify-between", s.type === currentType && "bg-primary/10 text-primary")}
          >
            <span className="flex items-center gap-2">
              <Icon aria-hidden className="h-3.5 w-3.5" />
              {s.label}
            </span>
            <span className="tabular-nums text-xs text-muted-foreground">
              {s.answeredCount}/{s.count}
            </span>
          </Button>
        );
      })}
    </aside>
  );
}
