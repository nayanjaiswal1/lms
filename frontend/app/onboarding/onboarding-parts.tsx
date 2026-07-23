"use client";

import {
  TrendingUp, Compass, Hammer, RefreshCw, ShieldCheck,
  Sprout, Puzzle, Layers, Gem,
  type LucideIcon,
} from "lucide-react";
import { cn } from "@/lib/utils";

// ─── Types ────────────────────────────────────────────────────────────────────

export type LearningGoalValue = "get_promotion" | "switch_careers" | "build_project" | "stay_current" | "compliance";
export type SkillLevelValue = "beginner" | "some_experience" | "intermediate" | "advanced";

// ─── Constants ────────────────────────────────────────────────────────────────

export const LEARNING_GOAL_OPTIONS: { value: LearningGoalValue; title: string; subtitle: string; icon: LucideIcon }[] = [
  { value: "get_promotion",  title: "Get a promotion",     subtitle: "Advance in my current role",              icon: TrendingUp },
  { value: "switch_careers", title: "Switch careers",       subtitle: "Move into a new field",                   icon: Compass },
  { value: "build_project",  title: "Build a side project", subtitle: "Apply skills to something I'm building",  icon: Hammer },
  { value: "stay_current",   title: "Stay current",         subtitle: "Keep up with trends in my field",         icon: RefreshCw },
  { value: "compliance",     title: "Compliance training",  subtitle: "Required training for my role",           icon: ShieldCheck },
];

export const SKILL_OPTIONS: { value: SkillLevelValue; title: string; subtitle: string; icon: LucideIcon }[] = [
  { value: "beginner",        title: "Beginner",        subtitle: "Little to no experience — starting from scratch", icon: Sprout },
  { value: "some_experience", title: "Some experience", subtitle: "Tried a few things, still building fundamentals",  icon: Puzzle },
  { value: "intermediate",    title: "Intermediate",    subtitle: "Comfortable with the basics, ready to go deeper",  icon: Layers },
  { value: "advanced",        title: "Advanced",        subtitle: "Strong foundation, looking for expert-level content", icon: Gem },
];

// ─── SelectionCard ────────────────────────────────────────────────────────────

interface SelectionCardProps {
  selected: boolean;
  onClick: () => void;
  title: string;
  subtitle: string;
  icon?: LucideIcon;
}

export function SelectionCard({ selected, onClick, title, subtitle, icon: Icon }: SelectionCardProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "card-interactive flex w-full items-center gap-3 p-3 text-left transition-all duration-normal",
        selected ? "ring-2 ring-primary bg-primary/5 border-primary/30" : "",
      )}
    >
      {Icon && (
        <span className={cn(
          "flex h-7 w-7 shrink-0 items-center justify-center rounded-md transition-colors duration-normal",
          selected ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground",
        )}>
          <Icon aria-hidden className="h-3.5 w-3.5" />
        </span>
      )}
      <span className="flex flex-col">
        <span className="text-sm font-semibold text-foreground">{title}</span>
        <span className="text-xs text-muted-foreground">{subtitle}</span>
      </span>
    </button>
  );
}
