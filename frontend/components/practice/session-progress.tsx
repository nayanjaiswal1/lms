import { CheckCircle2, Circle, MessageSquare } from "lucide-react";
import { cn } from "@/lib/utils";
import type { PracticeItem } from "@/lib/server/practice";

interface SessionProgressProps {
  items: PracticeItem[];
  currentPosition: number;
}

export function SessionProgress({ items, currentPosition }: SessionProgressProps) {
  const answered = items.filter((i) => i.answered_at !== null).length;
  const total = items.length;
  const pct = total > 0 ? Math.round((answered / total) * 100) : 0;

  return (
    <div className="card-base flex flex-col gap-4 p-4">
      <div className="flex items-center justify-between text-sm">
        <span className="font-medium">Progress</span>
        <span className="text-muted-foreground">{answered}/{total}</span>
      </div>

      <div className="progress-track">
        {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width */}
        <div className="progress-fill" style={{ "--progress": `${pct}%` } as React.CSSProperties} />
      </div>

      <ol className="flex flex-col gap-1.5" aria-label="Question list">
        {items.map((item) => {
          const isCurrent = item.position === currentPosition;
          const isAnswered = item.answered_at !== null;
          const hasFeedback = item.feedback_at !== null;

          return (
            <li
              key={item.id}
              className={cn(
                "flex items-center gap-2.5 rounded-md px-2 py-1.5 text-sm transition-colors duration-fast",
                isCurrent && "bg-muted font-medium",
              )}
              aria-current={isCurrent ? "step" : undefined}
            >
              {isAnswered ? (
                <CheckCircle2 aria-label="Answered" className="h-4 w-4 shrink-0 text-primary" />
              ) : (
                <Circle aria-label="Not answered" className="h-4 w-4 shrink-0 text-muted-foreground" />
              )}
              <span className="flex-1 line-clamp-1">Q{item.position + 1}</span>
              {hasFeedback && (
                <MessageSquare aria-label="Has AI feedback" className="h-3.5 w-3.5 shrink-0 text-ai" />
              )}
            </li>
          );
        })}
      </ol>
    </div>
  );
}
