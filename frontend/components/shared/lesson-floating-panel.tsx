"use client";

import { X } from "lucide-react";
import { Button } from "@/components/ui/button";

interface LessonFloatingPanelProps {
  ariaLabel: string;
  icon: React.ReactNode;
  title: string;
  headerExtra?: React.ReactNode;
  onClose: () => void;
  children: React.ReactNode;
  footer?: React.ReactNode;
}

// Shared shell for the small floating panels a lesson page can have open —
// "My notes", "Ask your AI", and the highlight "AI Explanation" card (only
// one at a time, coordinated via the `lessonPanel` URL param — see
// HighlightProvider). Same corner, same card chrome, same close affordance,
// so switching between them reads as one system instead of three
// differently-shaped overlays. Callers own their own body layout (including
// whether/where it scrolls) via `children` — this shell only owns the
// positioning wrapper, the opaque card frame, the header row, and the
// optional footer row.
export function LessonFloatingPanel({
  ariaLabel,
  icon,
  title,
  headerExtra,
  onClose,
  children,
  footer,
}: LessonFloatingPanelProps) {
  return (
    <div
      aria-label={ariaLabel}
      className="fixed bottom-4 inset-x-4 sm:inset-x-auto sm:right-4 sm:left-auto sm:w-full sm:max-w-sm z-modal animate-in slide-in-from-bottom-4 fade-in duration-normal ease-smooth"
      role="dialog"
    >
      {/* Floating overlay, not an inline card — needs an opaque backdrop of
          its own (unlike .ai-surface panels, which already sit on the page's
          solid bg-background). Border-only keeps the cyan AI accent without
          a see-through fill bleeding whatever's behind it into the panel. */}
      <div className="bg-background border border-ai/20 rounded-xl shadow-raised overflow-hidden flex flex-col max-h-[calc(100dvh-2rem)]">
        <div className="shrink-0 flex items-center justify-between px-4 py-3 border-b border-border">
          <div className="flex items-center gap-2">
            {icon}
            <span className="text-sm font-medium">{title}</span>
            {headerExtra}
          </div>
          <Button
            aria-label={`Close ${title}`}
            className="size-7 touch-target"
            size="icon"
            variant="ghost"
            onClick={onClose}
          >
            <X aria-hidden className="size-3.5" />
          </Button>
        </div>

        {children}

        {footer && (
          <div className="shrink-0 flex items-center justify-between px-4 py-3 border-t border-border">
            {footer}
          </div>
        )}
      </div>
    </div>
  );
}
