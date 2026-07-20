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

export async function RoundList({ plan }: RoundListProps) {
  const conceptual = plan.rounds?.find((r) => r.round_type === "conceptual");
  const coding = plan.rounds?.find((r) => r.round_type === "coding");

  const session = conceptual?.practice_session_id
    ? await getPracticeSession(conceptual.practice_session_id).catch(() => null)
    : null;

  const answered = session?.items?.filter((i) => i.answered_at !== null).length ?? 0;
  const total = session?.items?.length ?? 0;
  const conceptualDone = total > 0 && answered === total;
  const codingDone = coding?.status === "completed";
  const bothDone = conceptualDone && codingDone;

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
      <Link
        className="card-interactive flex items-center gap-4 p-5"
        href={session ? `${ROUTES.practiceSession(session.id)}?q=${Math.min(answered, Math.max(total - 1, 0))}` : "#"}
      >
        {conceptualDone ? (
          <CheckCircle2 aria-hidden className="h-6 w-6 shrink-0 text-primary" />
        ) : (
          <Circle aria-hidden className="h-6 w-6 shrink-0 text-muted-foreground" />
        )}
        <div className="flex flex-1 flex-col gap-1">
          <span className="font-medium">Round 1 · Conceptual</span>
          <span className="text-sm text-muted-foreground">
            {total > 0 ? `${answered}/${total} answered` : "Preparing questions…"}
          </span>
        </div>
        <Badge variant="outline">{conceptualDone ? "Completed" : "In progress"}</Badge>
      </Link>

      {/* Round 2 — coding */}
      {conceptualDone ? (
        <Link className="card-interactive flex items-center gap-4 p-5" href={ROUTES.interviewPrepCoding(plan.id)}>
          {codingDone ? (
            <CheckCircle2 aria-hidden className="h-6 w-6 shrink-0 text-primary" />
          ) : (
            <Circle aria-hidden className="h-6 w-6 shrink-0 text-muted-foreground" />
          )}
          <div className="flex flex-1 flex-col gap-1">
            <span className="font-medium">Round 2 · Coding</span>
            <span className="text-sm text-muted-foreground">
              {coding?.items?.length ?? 0} problem{(coding?.items?.length ?? 0) === 1 ? "" : "s"}
              {codingDone && coding?.score !== null && coding?.score !== undefined ? ` · ${Math.round(coding.score)}% passed` : ""}
            </span>
          </div>
          <Badge variant="outline">{codingDone ? "Completed" : "Start"}</Badge>
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

      {bothDone && (
        <Button asChild className="mt-2" size="lg">
          <Link href={ROUTES.interviewPrepReport(plan.id)}>View readiness report</Link>
        </Button>
      )}
    </div>
  );
}
