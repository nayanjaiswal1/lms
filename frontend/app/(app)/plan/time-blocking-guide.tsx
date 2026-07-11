"use client";

import * as React from "react";
import { X, Lightbulb, Clock, CheckCircle2, AlertCircle } from "lucide-react";

interface TimeBlockingGuideProps {
  onDismiss?: () => void;
}

export function TimeBlockingGuide({ onDismiss }: TimeBlockingGuideProps) {
  const [dismissed, setDismissed] = React.useState(false);

  if (dismissed) return null;

  return (
    <div className="rounded-lg border border-ai/20 bg-ai/5 p-4 sm:p-6">
      <div className="flex items-start justify-between gap-4">
        <div className="flex-1 space-y-4">
          <div className="flex items-center gap-2">
            <Lightbulb className="h-5 w-5 text-ai" />
            <h3 className="font-semibold">Time-Blocking Tips</h3>
          </div>

          <div className="space-y-3 text-sm">
            {/* Tip 1 */}
            <div className="flex gap-3">
              <div className="mt-0.5 flex-shrink-0">
                <Clock className="h-4 w-4 text-ai" />
              </div>
              <div>
                <p className="font-medium">Estimate realistic durations</p>
                <p className="text-xs text-muted-foreground">Add 20% buffer time for breaks and context switching</p>
              </div>
            </div>

            {/* Tip 2 */}
            <div className="flex gap-3">
              <div className="mt-0.5 flex-shrink-0">
                <CheckCircle2 className="h-4 w-4 text-ai" />
              </div>
              <div>
                <p className="font-medium">Create tasks for routine work</p>
                <p className="text-xs text-muted-foreground">Tasks can be reused and marked complete when done</p>
              </div>
            </div>

            {/* Tip 3 */}
            <div className="flex gap-3">
              <div className="mt-0.5 flex-shrink-0">
                <AlertCircle className="h-4 w-4 text-ai" />
              </div>
              <div>
                <p className="font-medium">Avoid back-to-back blocks</p>
                <p className="text-xs text-muted-foreground">Leave 15-30 min between intensive tasks for recovery</p>
              </div>
            </div>

            {/* Tip 4 */}
            <div className="flex gap-3">
              <div className="mt-0.5 flex-shrink-0">
                <Clock className="h-4 w-4 text-ai" />
              </div>
              <div>
                <p className="font-medium">Block time earlier in the day</p>
                <p className="text-xs text-muted-foreground">Most people are most productive in the morning</p>
              </div>
            </div>
          </div>

          {/* Quick start */}
          <div className="rounded-md bg-background/50 p-3">
            <p className="text-xs font-medium text-muted-foreground mb-2">Quick start:</p>
            <ol className="space-y-1.5 text-xs text-muted-foreground">
              <li>1. Click any time slot on the calendar</li>
              <li>2. Choose Event or Task</li>
              <li>3. Add a title and optional notes</li>
              <li>4. Use preset durations or set custom times</li>
              <li>5. Click Create to add to your schedule</li>
            </ol>
          </div>
        </div>

        {/* Close button */}
        <button
          onClick={() => {
            setDismissed(true);
            onDismiss?.();
          }}
          className="flex-shrink-0 text-muted-foreground transition-colors hover:text-foreground"
          aria-label="Dismiss guide"
        >
          <X className="h-5 w-5" />
        </button>
      </div>
    </div>
  );
}
