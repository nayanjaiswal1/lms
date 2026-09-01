"use client";

import { useReducer } from "react";

import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { fixEnglishAction } from "@/app/(app)/diary/actions";
import type { FixEnglishSegment } from "@/lib/server/diary";

interface ReviewState {
  status: "closed" | "loading" | "ready" | "error";
  segments: FixEnglishSegment[];
  // keyed by the del segment's index in `segments`; true = keep the "add"
  // replacement (default), false = reject it and keep the original "del" text.
  decisions: Record<number, boolean>;
}

type ReviewAction =
  | { type: "open" }
  | { type: "loaded"; segments: FixEnglishSegment[] }
  | { type: "error" }
  | { type: "toggle"; index: number }
  | { type: "set_all"; accept: boolean }
  | { type: "close" };

const initialState: ReviewState = { status: "closed", segments: [], decisions: {} };

function reviewReducer(state: ReviewState, action: ReviewAction): ReviewState {
  switch (action.type) {
    case "open":
      return { status: "loading", segments: [], decisions: {} };
    case "loaded":
      return { status: "ready", segments: action.segments, decisions: {} };
    case "error":
      return { status: "error", segments: [], decisions: {} };
    case "toggle":
      return { ...state, decisions: { ...state.decisions, [action.index]: !(state.decisions[action.index] ?? true) } };
    case "set_all": {
      const decisions: Record<number, boolean> = {};
      state.segments.forEach((seg, i) => {
        if (seg.kind === "del") decisions[i] = action.accept;
      });
      return { ...state, decisions };
    }
    case "close":
      return initialState;
    default:
      return state;
  }
}

// Reconstructs the final text: "same" segments pass through; each del/add
// pair resolves to "add" (accepted, the default) or "del" (rejected).
export function resolveFixEnglishText(segments: FixEnglishSegment[], decisions: Record<number, boolean>): string {
  let out = "";
  for (let i = 0; i < segments.length; i++) {
    const seg = segments[i];
    if (seg.kind === "same") {
      out += seg.text;
    } else if (seg.kind === "del") {
      const accepted = decisions[i] ?? true;
      out += accepted ? (segments[i + 1]?.text ?? "") : seg.text;
    }
    // "add" segments are consumed by their preceding "del" — skip here.
  }
  return out;
}

// Owns the review reducer + the AI call. DiaryEditor swaps its lined-paper
// write area for <DiaryFixEnglishReviewPanel> in place while state.status
// !== "closed" — no modal, so the review sits exactly where the entry text was.
export function useFixEnglishReview() {
  const [state, dispatch] = useReducer(reviewReducer, initialState);

  async function open(date: string, content: string) {
    dispatch({ type: "open" });
    const result = await fixEnglishAction(date, content);
    if (result.ok && result.data) dispatch({ type: "loaded", segments: result.data.segments });
    else dispatch({ type: "error" });
  }

  return {
    state,
    open,
    toggle: (index: number) => dispatch({ type: "toggle", index }),
    setAll: (accept: boolean) => dispatch({ type: "set_all", accept }),
    close: () => dispatch({ type: "close" }),
  };
}

interface DiaryFixEnglishReviewPanelProps {
  state: ReviewState;
  onToggle: (index: number) => void;
  onSetAll: (accept: boolean) => void;
  onCancel: () => void;
  onConfirm: () => void;
}

export function DiaryFixEnglishReviewPanel({
  state,
  onToggle,
  onSetAll,
  onCancel,
  onConfirm,
}: DiaryFixEnglishReviewPanelProps) {
  return (
    <div className="flex flex-col gap-4">
      <div className="diary-lined min-h-[400px] overflow-y-auto whitespace-pre-wrap text-base leading-8 text-foreground">
        {state.status === "loading" && <p className="text-sm text-muted-foreground">Checking your entry…</p>}
        {state.status === "error" && (
          <p className="text-sm text-destructive">Could not check this entry. Try again.</p>
        )}
        {state.status === "ready" && state.segments.every((s) => s.kind === "same") && (
          <p className="text-sm text-muted-foreground">No corrections found.</p>
        )}
        {state.status === "ready" &&
          state.segments.map((seg, i) => {
            if (seg.kind === "same") return <span key={i}>{seg.text}</span>;
            if (seg.kind === "add") return null; // rendered alongside its preceding "del"
            const accepted = state.decisions[i] ?? true;
            const addSeg = state.segments[i + 1];
            return (
              <span key={i}>
                <button
                  className={cn(
                    "rounded-sm px-0.5 line-through",
                    accepted ? "bg-muted text-muted-foreground" : "bg-destructive/10 text-destructive",
                  )}
                  title="Click to keep the original wording"
                  type="button"
                  onClick={() => onToggle(i)}
                >
                  {seg.text}
                </button>{" "}
                {addSeg && (
                  <button
                    className={cn(
                      "rounded-sm px-0.5",
                      accepted ? "bg-success/10 text-success" : "bg-muted text-muted-foreground line-through",
                    )}
                    title="Click to accept the correction"
                    type="button"
                    onClick={() => onToggle(i)}
                  >
                    {addSeg.text}
                  </button>
                )}{" "}
              </span>
            );
          })}
      </div>

      <div className="flex flex-wrap items-center justify-end gap-2">
        <Button disabled={state.status !== "ready"} size="sm" variant="outline" onClick={() => onSetAll(false)}>
          Reject all
        </Button>
        <Button disabled={state.status !== "ready"} size="sm" variant="outline" onClick={() => onSetAll(true)}>
          Accept all
        </Button>
        <Button size="sm" variant="ghost" onClick={onCancel}>
          Cancel
        </Button>
        <Button disabled={state.status !== "ready"} size="sm" onClick={onConfirm}>
          Save
        </Button>
      </div>
    </div>
  );
}
