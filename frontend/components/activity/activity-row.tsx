import Link from "next/link";
import {
  BookOpen,
  GraduationCap,
  ClipboardCheck,
  Sparkles,
  CheckCircle2,
  FlaskConical,
  RotateCw,
  type LucideIcon,
} from "lucide-react";

import ROUTES from "@/lib/routes";
import type { ActivityEntry, ActivityKind } from "@/lib/server/activity";

const KIND_META: Record<ActivityKind, { icon: LucideIcon; label: string; ai?: boolean }> = {
  module_completed: { icon: BookOpen, label: "Completed a module" },
  course_completed: { icon: GraduationCap, label: "Completed a course" },
  quiz_attempt: { icon: ClipboardCheck, label: "Quiz attempt" },
  reflection: { icon: Sparkles, label: "AI reflection", ai: true },
  sheet_problem_solved: { icon: CheckCircle2, label: "Solved a problem" },
  lab_completed: { icon: FlaskConical, label: "Completed a lab" },
  card_reviewed: { icon: RotateCw, label: "Reviewed a flashcard" },
};

function entryHref(entry: ActivityEntry): string | null {
  switch (entry.kind) {
    case "module_completed":
    case "reflection":
      return entry.ref_slug && entry.ref_id ? ROUTES.courseLearnModule(entry.ref_slug, entry.ref_id) : null;
    case "course_completed":
      return entry.ref_slug ? ROUTES.course(entry.ref_slug) : null;
    case "quiz_attempt":
      return entry.ref_id ? ROUTES.assessmentResult(entry.ref_id) : null;
    case "lab_completed":
      return entry.ref_id ? ROUTES.lab(entry.ref_id) : null;
    case "card_reviewed":
      return ROUTES.REVIEW;
    default:
      return null;
  }
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
}

export function ActivityRow({ entry }: { entry: ActivityEntry }) {
  const meta = KIND_META[entry.kind];
  const Icon = meta.icon;
  const href = entryHref(entry);

  const content = (
    <>
      <span
        className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-lg ${meta.ai ? "bg-ai/10" : "bg-primary/10"}`}
      >
        <Icon aria-hidden className={`h-4 w-4 ${meta.ai ? "text-ai" : "text-primary"}`} />
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-medium">{entry.title}</p>
        <p className="truncate text-xs text-muted-foreground">
          {meta.label}
          {entry.summary && <span> · {entry.summary}</span>}
          {" · "}
          {formatTime(entry.occurred_at)}
        </p>
      </div>
    </>
  );

  if (!href) {
    return <div className="flex items-center gap-3 p-3">{content}</div>;
  }

  return (
    <Link className="card-interactive flex items-center gap-3 p-3" href={href}>
      {content}
    </Link>
  );
}
