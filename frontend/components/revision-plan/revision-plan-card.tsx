import { Sparkles, AlertCircle, ListChecks } from "lucide-react";
import type { RevisionPlan } from "@/lib/server/revision-plan";
import { GenerateRevisionPlanButton } from "@/components/revision-plan/generate-revision-plan-button";
import { IconMessage } from "@/components/shared/icon-message";

interface RevisionPlanCardProps {
  courseId: string;
  plan: RevisionPlan | null;
}

// Shown once a course is fully completed (see courseComplete in the learn
// page). Reads the AI-generated ranked weak-topics plan built from the
// student's actual knowledge-check accuracy and their own lesson reflections
// (see backend/internal/revisionplan) — never a generic "review everything"
// list. The "generating" meta-refresh mirrors the exact pattern used by the
// roadmap detail page (see app/(app)/roadmap/[id]/page.tsx): a plain
// <meta http-equiv="refresh"> reloads the server component every 3s while
// generating, and stops on its own once status leaves "generating" since the
// tag is then simply absent — no client interval or useEffect needed.
export function RevisionPlanCard({ courseId, plan }: RevisionPlanCardProps) {
  if (!plan) {
    return (
      <div className="ai-surface flex flex-col gap-3 rounded-lg p-6">
        <div className="flex items-center gap-2">
          <Sparkles aria-hidden className="h-4 w-4 text-ai" />
          <span className="font-medium text-ai">Revision plan</span>
        </div>
        <p className="text-sm text-muted-foreground">
          Get an AI-built revision plan based on your actual knowledge-check accuracy and lesson
          reflections in this course — ranked weak topics, not a generic review list.
        </p>
        <GenerateRevisionPlanButton courseId={courseId} label="Generate my revision plan" />
      </div>
    );
  }

  return (
    <div className="ai-surface flex flex-col gap-4 rounded-lg p-6">
      {plan.status === "generating" && <meta content="3" httpEquiv="refresh" />}

      <div className="flex items-center gap-2">
        <Sparkles aria-hidden className="h-4 w-4 text-ai" />
        <span className="font-medium text-ai">Revision plan</span>
      </div>

      {plan.status === "generating" && (
        <IconMessage
          className="rounded-md border border-ai/20 bg-background/50 p-4"
          icon={Sparkles}
          size="md"
          tone="ai"
          variant="plain"
        >
          AI is analyzing your performance across this course. This page refreshes automatically.
        </IconMessage>
      )}

      {plan.status === "failed" && (
        <div className="flex flex-col gap-3">
          <div className="flex items-center gap-2 text-destructive">
            <AlertCircle aria-hidden className="h-4 w-4" />
            <span className="font-medium">Generation failed</span>
          </div>
          <p className="text-sm text-muted-foreground">
            {plan.generation_error ?? "Something went wrong while generating your revision plan."}
          </p>
          <GenerateRevisionPlanButton courseId={courseId} label="Try again" />
        </div>
      )}

      {plan.status === "ready" && plan.topics && plan.topics.length > 0 && (
        <ol className="flex flex-col gap-3">
          {plan.topics.map((topic) => (
            <li className="flex flex-col gap-1 rounded-lg border border-border p-3" key={topic.id}>
              <div className="flex items-start gap-2">
                <ListChecks aria-hidden className="mt-0.5 h-3.5 w-3.5 shrink-0 text-primary" />
                <span className="text-sm font-medium">{topic.title}</span>
              </div>
              <p className="text-xs text-muted-foreground">{topic.reason}</p>
              <p className="text-xs text-foreground">{topic.recommendation}</p>
            </li>
          ))}
        </ol>
      )}
    </div>
  );
}
