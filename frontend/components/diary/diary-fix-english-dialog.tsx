"use client";

import { useReducer } from "react";
import { Wand2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
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
      return { status: "closed", segments: [], decisions: {} };
    default:
      return state;
  }
}

// Reconstructs the final text: "same" segments pass through; each del/add
// pair resolves to "add" (accepted, the default) or "del" (rejected).
function resolveText(segments: FixEnglishSegment[], decisions: Record<number, boolean>): string {
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

interface DiaryFixEnglishDialogProps {
  date: string;
  content: string;
  onApply: (next: string) => void;
}

export function DiaryFixEnglishDialog({ date, content, onApply }: DiaryFixEnglishDialogProps) {
  const [state, dispatch] = useReducer(reviewReducer, { status: "closed", segments: [], decisions: {} });

  async function handleOpenChange(open: boolean) {
    if (!open) {
      dispatch({ type: "close" });
      return;
    }
    dispatch({ type: "open" });
    const result = await fixEnglishAction(date, content);
    if (result.ok && result.data) dispatch({ type: "loaded", segments: result.data.segments });
    else dispatch({ type: "error" });
  }

  function handleConfirm() {
    onApply(resolveText(state.segments, state.decisions));
    dispatch({ type: "close" });
  }

  return (
    <Dialog open={state.status !== "closed"} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>
        <Button className="gap-1.5 text-muted-foreground hover:text-foreground" size="sm" variant="ghost">
          <Wand2 aria-hidden className="size-4" />
          Fix English
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive max-w-2xl">
        <DialogHeader>
          <DialogTitle>Review corrections</DialogTitle>
        </DialogHeader>

        {state.status === "loading" && <p className="text-sm text-muted-foreground">Checking your entry…</p>}
        {state.status === "error" && <p className="text-sm text-destructive">Could not check this entry. Try again.</p>}
        {state.status === "ready" && state.segments.every((s) => s.kind === "same") && (
          <p className="text-sm text-muted-foreground">No corrections found.</p>
        )}

        {state.status === "ready" && (
          <div className="max-h-[50vh] overflow-y-auto whitespace-pre-wrap text-base leading-8 text-foreground">
            {state.segments.map((seg, i) => {
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
                    onClick={() => dispatch({ type: "toggle", index: i })}
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
                      onClick={() => dispatch({ type: "toggle", index: i })}
                    >
                      {addSeg.text}
                    </button>
                  )}{" "}
                </span>
              );
            })}
          </div>
        )}

        <DialogFooter>
          <Button
            disabled={state.status !== "ready"}
            variant="outline"
            onClick={() => dispatch({ type: "set_all", accept: false })}
          >
            Reject all
          </Button>
          <Button disabled={state.status !== "ready"} variant="outline" onClick={() => dispatch({ type: "set_all", accept: true })}>
            Accept all
          </Button>
          <Button disabled={state.status !== "ready"} onClick={handleConfirm}>
            Save
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
