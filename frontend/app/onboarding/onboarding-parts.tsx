"use client";

import type { LucideIcon } from "lucide-react";
import { cn } from "@/lib/utils";

// ─── Types ────────────────────────────────────────────────────────────────────

export type LearningGoalValue = "get_promotion" | "switch_careers" | "build_project" | "stay_current" | "compliance";
export type TimeCommitmentValue = "1_2_hrs" | "3_5_hrs" | "5_10_hrs" | "10_plus_hrs";
export type SkillLevelValue = "beginner" | "some_experience" | "intermediate" | "advanced";

// ─── Constants ────────────────────────────────────────────────────────────────

export const ROLE_SUGGESTIONS = [
  "Software Engineer", "Designer", "Product Manager", "Data Analyst",
  "Student", "Marketing", "DevOps", "Other",
] as const;

export const LEARNING_GOAL_OPTIONS: { value: LearningGoalValue; title: string; subtitle: string }[] = [
  { value: "get_promotion",  title: "Get a promotion",     subtitle: "Advance in my current role" },
  { value: "switch_careers", title: "Switch careers",       subtitle: "Move into a new field" },
  { value: "build_project",  title: "Build a side project", subtitle: "Apply skills to something I'm building" },
  { value: "stay_current",   title: "Stay current",         subtitle: "Keep up with trends in my field" },
  { value: "compliance",     title: "Compliance training",  subtitle: "Required training for my role" },
];

export const TOPICS: { value: string; label: string }[] = [
  { value: "software_dev",   label: "Software Development" },
  { value: "data_science",   label: "Data & AI" },
  { value: "design",         label: "Design" },
  { value: "product",        label: "Product Management" },
  { value: "devops",         label: "DevOps & Cloud" },
  { value: "security",       label: "Security" },
  { value: "marketing",      label: "Marketing" },
  { value: "leadership",     label: "Leadership" },
  { value: "finance",        label: "Finance" },
  { value: "communication",  label: "Communication" },
  { value: "language",       label: "Languages" },
  { value: "other",          label: "Other" },
];

export const TIME_OPTIONS: { value: TimeCommitmentValue; title: string; subtitle: string }[] = [
  { value: "1_2_hrs",     title: "1–2 hours",  subtitle: "Light · About 15–20 min per session" },
  { value: "3_5_hrs",     title: "3–5 hours",  subtitle: "Moderate · 3–4 sessions per week" },
  { value: "5_10_hrs",    title: "5–10 hours", subtitle: "Dedicated · Daily sessions" },
  { value: "10_plus_hrs", title: "10+ hours",  subtitle: "Intensive · Multiple sessions per day" },
];

export const SKILL_OPTIONS: { value: SkillLevelValue; title: string; subtitle: string }[] = [
  { value: "beginner",        title: "Beginner",        subtitle: "Little to no experience — starting from scratch" },
  { value: "some_experience", title: "Some experience", subtitle: "Tried a few things, still building fundamentals" },
  { value: "intermediate",    title: "Intermediate",    subtitle: "Comfortable with the basics, ready to go deeper" },
  { value: "advanced",        title: "Advanced",        subtitle: "Strong foundation, looking for expert-level content" },
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
        "card-interactive flex min-h-24 w-full items-start gap-4 p-5 text-left transition-all duration-normal",
        selected ? "ring-2 ring-primary bg-primary/5 border-primary/30" : "",
      )}
    >
      {Icon && (
        <span className={cn(
          "mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-md transition-colors duration-normal",
          selected ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground",
        )}>
          <Icon aria-hidden className="h-4 w-4" />
        </span>
      )}
      <span className="flex flex-col gap-1">
        <span className="font-semibold text-foreground">{title}</span>
        <span className="text-sm text-muted-foreground">{subtitle}</span>
      </span>
    </button>
  );
}

// ─── StepIndicator ────────────────────────────────────────────────────────────

export function StepIndicator({ current, total }: { current: number; total: number }) {
  return (
    <div className="flex items-center gap-3">
      <div className="flex gap-1.5">
        {Array.from({ length: total }, (_, i) => (
          <span
            key={i}
            className={cn(
              "h-1.5 rounded-full transition-all duration-normal",
              i < current ? "w-6 bg-primary" : i === current ? "w-4 bg-primary" : "w-1.5 bg-muted",
            )}
          />
        ))}
      </div>
      <span className="text-xs text-muted-foreground">Step {current + 1} of {total}</span>
    </div>
  );
}

// ─── TopicGrid ────────────────────────────────────────────────────────────────

interface TopicGridProps {
  selected: string[];
  onToggle: (value: string) => void;
}

export function TopicGrid({ selected, onToggle }: TopicGridProps) {
  return (
    <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
      {TOPICS.map((topic) => {
        const isSelected = selected.includes(topic.value);
        return (
          <button
            key={topic.value}
            type="button"
            onClick={() => onToggle(topic.value)}
            className={cn(
              "rounded-lg border px-4 py-3 text-sm font-medium text-left transition-all duration-normal",
              isSelected
                ? "ring-2 ring-primary bg-primary/5 border-primary/30 text-foreground"
                : "border-border bg-card text-muted-foreground hover:border-primary/40 hover:text-foreground",
            )}
          >
            {topic.label}
          </button>
        );
      })}
    </div>
  );
}
