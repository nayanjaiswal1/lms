import { CheckCircle2, AlertCircle, Lightbulb, BookOpen } from "lucide-react";
import type { AIFeedback } from "@/lib/server/practice";

interface AIFeedbackCardProps {
  feedback: AIFeedback;
}

export function AIFeedbackCard({ feedback }: AIFeedbackCardProps) {
  const scorePct = Math.round((feedback.score / feedback.max_score) * 100);

  return (
    <div className="ai-surface flex flex-col gap-5 rounded-lg p-5">
      <div className="flex items-center justify-between gap-2">
        <div className="ai-badge">AI Feedback</div>
        <div className="flex items-baseline gap-1">
          <span className="text-2xl font-bold text-primary">{feedback.score}</span>
          <span className="text-sm text-muted-foreground">/ {feedback.max_score}</span>
          <span className="ml-1 text-sm text-muted-foreground">({scorePct}%)</span>
        </div>
      </div>

      {feedback.strengths.length > 0 && (
        <section className="flex flex-col gap-2">
          <h4 className="flex items-center gap-1.5 text-sm font-semibold">
            <CheckCircle2 aria-hidden className="h-4 w-4 text-primary" />
            Strengths
          </h4>
          <ul className="flex flex-col gap-1 pl-1">
            {feedback.strengths.map((s, i) => (
              <li key={i} className="text-sm text-foreground">{s}</li>
            ))}
          </ul>
        </section>
      )}

      {feedback.gaps.length > 0 && (
        <section className="flex flex-col gap-2">
          <h4 className="flex items-center gap-1.5 text-sm font-semibold">
            <AlertCircle aria-hidden className="h-4 w-4 text-muted-foreground" />
            Areas to improve
          </h4>
          <ul className="flex flex-col gap-1 pl-1">
            {feedback.gaps.map((g, i) => (
              <li key={i} className="text-sm text-muted-foreground">{g}</li>
            ))}
          </ul>
        </section>
      )}

      {feedback.suggested_answer && (
        <section className="flex flex-col gap-2">
          <h4 className="flex items-center gap-1.5 text-sm font-semibold">
            <Lightbulb aria-hidden className="h-4 w-4 text-ai" />
            Suggested answer
          </h4>
          <p className="whitespace-pre-wrap text-sm text-muted-foreground">{feedback.suggested_answer}</p>
        </section>
      )}

      {feedback.follow_up_resources.length > 0 && (
        <section className="flex flex-col gap-2">
          <h4 className="flex items-center gap-1.5 text-sm font-semibold">
            <BookOpen aria-hidden className="h-4 w-4 text-muted-foreground" />
            Further reading
          </h4>
          <ul className="flex flex-col gap-1 pl-1">
            {feedback.follow_up_resources.map((r, i) => (
              <li key={i} className="text-sm text-muted-foreground">{r}</li>
            ))}
          </ul>
        </section>
      )}

      <p className="text-xs text-muted-foreground">Powered by {feedback.model}</p>
    </div>
  );
}
