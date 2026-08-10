"use client";

import { useEffect, useState, useTransition } from "react";
import { createPortal } from "react-dom";
import { useQueryState } from "nuqs";
import { Loader2, Maximize2, MessageCircleQuestion, Minimize2, NotebookText } from "lucide-react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import type { Segment } from "@/lib/courses/markdown";
import type { DesignAttempt, DesignAttemptSummary, DesignChatMessage } from "@/lib/design";
import { getDesignAttemptAction } from "@/lib/design-actions";
import { Button } from "@/components/ui/button";
import { ResizablePanelGroup, ResizablePanel, ResizableHandle } from "@/components/ui/resizable";
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
  const [isOpen, setIsOpen] = useState(false);

  // In-page overlay, not the browser's real Fullscreen API — it fills the
  // viewport inside the tab (browser chrome, tabs, etc. stay visible), so
  // Esc has no built-in meaning here; wire it and lock background scroll
  // ourselves while the overlay is up.
  useEffect(() => {
    if (!isOpen) return;
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") setIsOpen(false);
    };
    document.addEventListener("keydown", onKeyDown);
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKeyDown);
      document.body.style.overflow = prevOverflow;
    };
  }, [isOpen]);

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

  if (!isOpen) {
    return (
      <div className="card-base flex flex-col gap-4">
        <div className="flex justify-end">
          <Button className="shrink-0" size="sm" onClick={() => setIsOpen(true)}>
            <Maximize2 aria-hidden className="h-3.5 w-3.5" />Open whiteboard
          </Button>
        </div>
        <DesignGuidancePanel segments={guidanceSegments} />
      </div>
    );
  }

  // Portaled to document.body: this page's right rail is `position: sticky`
  // with no z-index of its own, and a `fixed` overlay nested inside the
  // article does not reliably paint above a sticky sibling in the same
  // stacking context — it was bleeding through next to the canvas. A body
  // portal sidesteps ancestor stacking entirely, same as Radix's own
  // popper/dialog content.
  return createPortal(
    <div className="fixed inset-0 z-modal safe-inset bg-background p-4">
      <ResizablePanelGroup orientation="horizontal">
        <ResizablePanel
          className="flex flex-col gap-3 overflow-hidden rounded-lg border border-border bg-card p-4"
          defaultSize="26%"
          id="design-guidance"
          maxSize="45%"
          minSize="20%"
        >
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
          <div className="min-h-0 flex-1 overflow-x-hidden overflow-y-auto">
            {tab === "chat" ? (
              <DesignChatPanel initialMessages={initialChat} moduleId={moduleId} />
            ) : (
              <DesignGuidancePanel segments={guidanceSegments} />
            )}
          </div>
        </ResizablePanel>

        <ResizableHandle withHandle className="mx-2" orientation="horizontal" />

        <ResizablePanel defaultSize="74%" id="design-canvas" minSize="40%">
          <section className="flex h-full min-h-0 flex-col gap-3">
            <div className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-border bg-card p-3">
              <DesignAttemptSelector
                attempts={attempts}
                moduleId={moduleId}
                selectedAttemptId={selected?.id}
                onCreated={handleCreated}
                onSelect={selectAttempt}
              />
              <div className="flex items-center gap-2">
                {selected && (
                  <DesignFeedbackPanel attemptId={selected.id} initialFeedback={selected.feedback} moduleId={moduleId} />
                )}
                <Button
                  aria-label="Close whiteboard"
                  className="touch-target text-muted-foreground"
                  size="icon"
                  variant="ghost"
                  onClick={() => setIsOpen(false)}
                >
                  <Minimize2 aria-hidden className="h-4 w-4" />
                </Button>
              </div>
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
                  <p className="text-sm text-muted-foreground">
                    Use the <strong className="text-foreground">+</strong> above to start your first attempt and open the whiteboard.
                  </p>
                </div>
              )}
            </div>
          </section>
        </ResizablePanel>
      </ResizablePanelGroup>
    </div>,
    document.body,
  );
}
