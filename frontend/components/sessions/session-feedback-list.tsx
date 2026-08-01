import { Star } from "lucide-react";
import type { FeedbackAuthorRole, SessionFeedback } from "@/lib/server/sessions";

// ponytail: hardcoded label instead of resolveTerminology() — that helper
// needs the org's org_type, which SessionDetail (lib/server/sessions.ts)
// doesn't return, and fetching org context is out of scope for this file set.
const ROLE_LABEL: Record<FeedbackAuthorRole, string> = {
  student: "Student",
  mentor: "Mentor",
};

interface SessionFeedbackListProps {
  feedback: SessionFeedback[];
}

export function SessionFeedbackList({ feedback }: SessionFeedbackListProps) {
  if (feedback.length === 0) return null;

  return (
    <section className="flex flex-col gap-4">
      <h2 className="section-title">Feedback</h2>
      <div className="flex flex-col gap-3">
        {feedback.map((entry) => (
          <div className="rounded-lg border border-border bg-card p-4" key={entry.id}>
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="flex min-w-0 items-center gap-2">
                <span className="truncate font-medium text-foreground">
                  {entry.author_name ?? ROLE_LABEL[entry.author_role]}
                </span>
                <span className="text-xs text-muted-foreground">{ROLE_LABEL[entry.author_role]}</span>
              </div>
              <span aria-hidden className="flex items-center gap-0.5 text-primary">
                {[1, 2, 3, 4, 5].map((n) => (
                  <Star className="h-3.5 w-3.5" fill={n <= entry.rating ? "currentColor" : "none"} key={n} />
                ))}
              </span>
            </div>
            {entry.comment && <p className="mt-2 text-sm text-muted-foreground">{entry.comment}</p>}
          </div>
        ))}
      </div>
    </section>
  );
}
