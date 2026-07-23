import Link from "next/link";
import { CheckCircle2, Circle, Lock } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";
import type { PrepPlan } from "@/lib/server/interview-prep";
import { getPracticeSession } from "@/lib/server/practice";

interface RoundListProps {
  plan: PrepPlan;
}

// The primary round is whichever practice-session-backed round starts the
// plan — "conceptual" for technical plans, "behavioral" for non-technical
// ones. Both are answered through the same /practice/[sessionId] UI, just
// with different generated content. A secondary "coding" round only exists
// for technical, targeted plans — quick plans and non-technical targeted
// plans are single-round.
export async function RoundList({ plan }: RoundListProps) {
  const primary = plan.rounds?.find((r) => r.round_type === "conceptual" || r.round_type === "behavioral");
  const secondary = plan.rounds?.find((r) => r.round_type === "coding");

  const session = primary?.practice_session_id
    ? await getPracticeSession(primary.practice_session_id).catch(() => null)
    : null;

  const answered = session?.items?.filter((i) => i.answered_at !== null).length ?? 0;
  const total = session?.items?.length ?? 0;
  const primaryDone = total > 0 && answered === total;
  const secondaryDone = secondary?.status === "completed";
  const readyForReport = primaryDone && (!secondary || secondaryDone);

  const primaryHref = session
    ? `${ROUTES.practiceSession(session.id)}?q=${Math.min(answered, Math.max(total - 1, 0))}`
    : "#";

  const isBehavioral = primary?.round_type === "behavioral";
  const primaryLabel = secondary ? "Round 1 · Conceptual" : isBehavioral ? "Behavioral Round" : "Practice Session";

  if (!secondary) {
    return (
      <div className="flex flex-col gap-4">
        {plan.plan_type === "targeted" && (
          <div className="ai-surface rounded-lg p-4">
            <p className="text-sm">
              <span className="font-medium">{plan.extracted_role}</span> · <span className="capitalize">{plan.extracted_seniority}</span>
            </p>
            <div className="mt-2 flex flex-wrap gap-1.5">
              {plan.extracted_skills.map((skill) => (
                <Badge className="text-xs" key={skill} variant="outline">{skill}</Badge>
              ))}
            </div>
          </div>
        )}
        <Link className="card-interactive flex items-center gap-4 p-5" href={primaryHref}>
          {primaryDone ? (
            <CheckCircle2 aria-hidden className="h-6 w-6 shrink-0 text-primary" />
          ) : (
            <Circle aria-hidden className="h-6 w-6 shrink-0 text-muted-foreground" />
          )}
          <div className="flex flex-1 flex-col gap-1">
            <span className="font-medium">{primaryLabel}</span>
            <span className="text-sm text-muted-foreground">
              {total > 0 ? `${answered}/${total} answered` : "Preparing questions…"}
            </span>
          </div>
          <Badge variant="outline">{primaryDone ? "Completed" : "In progress"}</Badge>
        </Link>

        {/* Quick plans never generate a report; non-technical targeted plans do. */}
        {plan.plan_type === "targeted" && readyForReport && (
          <Button asChild className="mt-2" size="lg">
            <Link href={ROUTES.interviewPrepReport(plan.id)}>View readiness report</Link>
          </Button>
        )}
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="ai-surface rounded-lg p-4">
        <p className="text-sm">
          <span className="font-medium">{plan.extracted_role}</span> · <span className="capitalize">{plan.extracted_seniority}</span>
        </p>
        <div className="mt-2 flex flex-wrap gap-1.5">
          {plan.extracted_skills.map((skill) => (
            <Badge className="text-xs" key={skill} variant="outline">{skill}</Badge>
          ))}
        </div>
      </div>

      {/* Round 1 — conceptual */}
      <Link className="card-interactive flex items-center gap-4 p-5" href={primaryHref}>
        {primaryDone ? (
          <CheckCircle2 aria-hidden className="h-6 w-6 shrink-0 text-primary" />
        ) : (
          <Circle aria-hidden className="h-6 w-6 shrink-0 text-muted-foreground" />
        )}
        <div className="flex flex-1 flex-col gap-1">
          <span className="font-medium">{primaryLabel}</span>
          <span className="text-sm text-muted-foreground">
            {total > 0 ? `${answered}/${total} answered` : "Preparing questions…"}
          </span>
        </div>
        <Badge variant="outline">{primaryDone ? "Completed" : "In progress"}</Badge>
      </Link>

      {/* Round 2 — coding */}
      {primaryDone ? (
        <Link className="card-interactive flex items-center gap-4 p-5" href={ROUTES.interviewPrepCoding(plan.id)}>
          {secondaryDone ? (
            <CheckCircle2 aria-hidden className="h-6 w-6 shrink-0 text-primary" />
          ) : (
            <Circle aria-hidden className="h-6 w-6 shrink-0 text-muted-foreground" />
          )}
          <div className="flex flex-1 flex-col gap-1">
            <span className="font-medium">Round 2 · Coding</span>
            <span className="text-sm text-muted-foreground">
              {secondary?.items?.length ?? 0} problem{(secondary?.items?.length ?? 0) === 1 ? "" : "s"}
              {secondaryDone && secondary?.score !== null && secondary?.score !== undefined
                ? ` · ${Math.round(secondary.score)}% passed`
                : ""}
            </span>
          </div>
          <Badge variant="outline">{secondaryDone ? "Completed" : "Start"}</Badge>
        </Link>
      ) : (
        <div className={cn("card-base flex items-center gap-4 p-5 opacity-60")}>
          <Lock aria-hidden className="h-6 w-6 shrink-0 text-muted-foreground" />
          <div className="flex flex-1 flex-col gap-1">
            <span className="font-medium">Round 2 · Coding</span>
            <span className="text-sm text-muted-foreground">Complete Round 1 to unlock</span>
          </div>
        </div>
      )}

      {readyForReport && (
        <Button asChild className="mt-2" size="lg">
          <Link href={ROUTES.interviewPrepReport(plan.id)}>View readiness report</Link>
        </Button>
      )}
    </div>
  );
}
