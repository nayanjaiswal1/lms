"use client";

import { useState, useTransition } from "react";
import { useQueryState } from "nuqs";
import { Loader2, MessageCircleQuestion, NotebookText } from "lucide-react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import type { Segment } from "@/lib/courses/markdown";
import type { DesignAttempt, DesignAttemptSummary, DesignChatMessage } from "@/lib/design";
import { getDesignAttemptAction } from "@/lib/design-actions";
import { DesignAttemptSelector } from "@/components/courses/design-attempt-selector";
import { DesignCanvas } from "@/components/courses/design-canvas";
import { DesignChatPanel } from "@/components/courses/design-chat-panel";
import { DesignFeedbackPanel } from "@/components/courses/design-feedback-panel";
import { DesignGuidancePanel } from "@/components/courses/design-guidance-panel";

interface ModuleSystemDesignClientProps {
  moduleId: string;
  title: string;
  guidanceSegments: Segment[];
  initialAttempts: DesignAttemptSummary[];
  initialSelected: DesignAttempt | null;
  initialChat: DesignChatMessage[];
}

export function ModuleSystemDesignClient({
  moduleId,
  title,
  guidanceSegments,
  initialAttempts,
  initialSelected,
  initialChat,
}: ModuleSystemDesignClientProps) {
  const [tab, setTab] = useQueryState("panel", { defaultValue: "guidance" });
  const [attempts, setAttempts] = useState(initialAttempts);
  const [selected, setSelected] = useState(initialSelected);
  const [isSwitching, startSwitching] = useTransition();

  const selectAttempt = (attemptId: string) => {
    if (attemptId === selected?.id) return;
    startSwitching(async () => {
      const result = await getDesignAttemptAction(moduleId, attemptId);
      if (result.error || !result.data) {
        toast.error(result.error ?? "Failed to load that attempt.");
        return;
      }
      setSelected(result.data);
    });
  };

  const handleCreated = (summary: DesignAttemptSummary) => {
    setAttempts((prev) => [...prev, summary]);
    selectAttempt(summary.id);
  };

  return (
    <div className="flex h-[calc(100dvh-8rem)] min-h-[32rem] flex-col gap-3 lg:h-[85dvh] lg:flex-row">
      <aside className="flex h-64 shrink-0 flex-col gap-3 overflow-hidden rounded-lg border border-border bg-card p-4 lg:h-full lg:w-[360px]">
        <h2 className="text-lg font-semibold tracking-tight">{title}</h2>
        <div className="flex gap-1 rounded-lg bg-muted p-1">
          <button
            className={cn(
              "touch-target flex flex-1 items-center justify-center gap-1.5 rounded-md text-xs font-medium transition-colors duration-fast",
              tab === "guidance" ? "bg-card shadow-card" : "text-muted-foreground",
            )}
            type="button"
            onClick={() => void setTab("guidance")}
          >
            <NotebookText aria-hidden className="h-3.5 w-3.5" />How to answer
          </button>
          <button
            className={cn(
              "touch-target flex flex-1 items-center justify-center gap-1.5 rounded-md text-xs font-medium transition-colors duration-fast",
              tab === "chat" ? "bg-card shadow-card" : "text-muted-foreground",
            )}
            type="button"
            onClick={() => void setTab("chat")}
          >
            <MessageCircleQuestion aria-hidden className="h-3.5 w-3.5" />Ask clarifying questions
          </button>
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto">
          {tab === "chat" ? (
            <DesignChatPanel initialMessages={initialChat} moduleId={moduleId} />
          ) : (
            <DesignGuidancePanel segments={guidanceSegments} />
          )}
        </div>
      </aside>

      <section className="flex min-h-0 flex-1 flex-col gap-3">
        <div className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-border bg-card p-3">
          <DesignAttemptSelector
            attempts={attempts}
            moduleId={moduleId}
            selectedAttemptId={selected?.id}
            onCreated={handleCreated}
            onSelect={selectAttempt}
          />
          {selected && (
            <DesignFeedbackPanel attemptId={selected.id} initialFeedback={selected.feedback} moduleId={moduleId} />
          )}
        </div>

        <div className="relative min-h-0 flex-1 overflow-hidden rounded-lg border border-border">
          {isSwitching && (
            <div className="absolute inset-0 z-overlay flex items-center justify-center bg-background/70">
              <Loader2 aria-hidden className="h-6 w-6 animate-spin text-muted-foreground" />
            </div>
          )}
          {selected ? (
            <DesignCanvas attemptId={selected.id} initialScene={selected.scene} key={selected.id} moduleId={moduleId} />
          ) : (
            <div className="empty-state h-full">
              <p className="text-sm text-muted-foreground">Start your first attempt to open the whiteboard.</p>
              <DesignAttemptSelector
                attempts={attempts}
                moduleId={moduleId}
                selectedAttemptId={undefined}
                onCreated={handleCreated}
                onSelect={selectAttempt}
              />
            </div>
          )}
        </div>
      </section>
    </div>
  );
}
