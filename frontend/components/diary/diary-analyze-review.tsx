"use client";

import { useReducer } from "react";

import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { analyzePreviewAction } from "@/app/(app)/diary/actions";
import type { DiaryHighlight, HighlightKind } from "@/lib/server/diary";

interface ReviewItem {
  highlight: DiaryHighlight;
  included: boolean;
  // Editable copy of highlight.text — only meaningful for task_new/buy_new,
  // where it becomes the captured task's title.
  text: string;
  // Editable copy of highlight.metadata (values stringified for <Input>) —
  // only meaningful for kind "habit". Coerced back to the field's real type
  // downstream by the habit entry form's own zod schema, same as a value
  // typed there directly.
  metadata: Record<string, string>;
}

interface ReviewState {
  status: "closed" | "loading" | "ready" | "error";
  items: ReviewItem[];
}

type ReviewAction =
  | { type: "open" }
  | { type: "loaded"; highlights: DiaryHighlight[] }
  | { type: "error" }
  | { type: "toggle"; index: number }
  | { type: "edit_text"; index: number; text: string }
  | { type: "edit_metadata"; index: number; key: string; value: string }
  | { type: "close" };

const initialState: ReviewState = { status: "closed", items: [] };

function toEditableMetadata(metadata: Record<string, unknown> | undefined): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [key, value] of Object.entries(metadata ?? {})) out[key] = String(value);
  return out;
}

function reviewReducer(state: ReviewState, action: ReviewAction): ReviewState {
  switch (action.type) {
    case "open":
      return { status: "loading", items: [] };
    case "loaded":
      return {
        status: "ready",
        items: action.highlights.map((highlight) => ({
          highlight,
          included: true,
          text: highlight.text,
          metadata: toEditableMetadata(highlight.metadata),
        })),
      };
    case "error":
      return { status: "error", items: [] };
    case "toggle": {
      const items = [...state.items];
      items[action.index] = { ...items[action.index], included: !items[action.index].included };
      return { ...state, items };
    }
    case "edit_text": {
      const items = [...state.items];
      items[action.index] = { ...items[action.index], text: action.text };
      return { ...state, items };
    }
    case "edit_metadata": {
      const items = [...state.items];
      const item = items[action.index];
      items[action.index] = { ...item, metadata: { ...item.metadata, [action.key]: action.value } };
      return { ...state, items };
    }
    case "close":
      return initialState;
    default:
      return state;
  }
}

// Reduces the review's edited items to the highlight list AnalyzeApply
// expects — only kept (checked) items, with any inline text/metadata edits
// folded back in.
export function resolveAnalyzeHighlights(items: ReviewItem[]): DiaryHighlight[] {
  return items
    .filter((item) => item.included)
    .map((item) => ({
      ...item.highlight,
      text: item.text,
      metadata: item.highlight.kind === "habit" && Object.keys(item.metadata).length > 0 ? item.metadata : undefined,
    }));
}

// Owns the review reducer + the preview AI call. DiaryEditor swaps its
// lined-paper write area for <DiaryAnalyzeReviewPanel> in place while
// state.status !== "closed" — items can arrive either from a fresh
// analyzePreviewAction call (open) or already-detected from the combined
// "AI" button's reviewDumpAction (loadFromHighlights), which skips the AI
// round trip since Preview already ran server-side.
export function useAnalyzeReview() {
  const [state, dispatch] = useReducer(reviewReducer, initialState);

  async function open(date: string, content: string) {
    dispatch({ type: "open" });
    const result = await analyzePreviewAction(date, content);
    if (result.ok && result.data) dispatch({ type: "loaded", highlights: result.data.highlights });
    else dispatch({ type: "error" });
  }

  return {
    state,
    open,
    // Loads an already-detected highlight list directly (e.g. from the
    // combined "AI" button's reviewDumpAction, which ran Preview server-side
    // already) — skips a second AI round trip.
    loadFromHighlights: (highlights: DiaryHighlight[]) => dispatch({ type: "loaded", highlights }),
    toggle: (index: number) => dispatch({ type: "toggle", index }),
    editText: (index: number, text: string) => dispatch({ type: "edit_text", index, text }),
    editMetadata: (index: number, key: string, value: string) =>
      dispatch({ type: "edit_metadata", index, key, value }),
    close: () => dispatch({ type: "close" }),
  };
}

const KIND_LABEL: Record<HighlightKind, string> = {
  habit: "Habit",
  task_done: "Task done",
  task_new: "New task",
  buy_new: "Buy list",
  learned: "📚 Learned",
  goal: "🎯 New goal",
};

function humanizeKey(key: string): string {
  return key.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

interface DiaryAnalyzeReviewPanelProps {
  state: ReviewState;
  onToggle: (index: number) => void;
  onEditText: (index: number, text: string) => void;
  onEditMetadata: (index: number, key: string, value: string) => void;
  onCancel: () => void;
  onConfirm: () => void;
}

export function DiaryAnalyzeReviewPanel({
  state,
  onToggle,
  onEditText,
  onEditMetadata,
  onCancel,
  onConfirm,
}: DiaryAnalyzeReviewPanelProps) {
  return (
    <div className="flex flex-col gap-4">
      <div className="diary-lined flex min-h-[400px] flex-col gap-3 overflow-y-auto p-4">
        {state.status === "loading" && <p className="text-sm text-muted-foreground">Scanning your entry…</p>}
        {state.status === "error" && (
          <p className="text-sm text-destructive">Could not analyze this entry. Try again.</p>
        )}
        {state.status === "ready" && state.items.length === 0 && (
          <p className="text-sm text-muted-foreground">No habits or tasks detected.</p>
        )}
        {state.status === "ready" &&
          state.items.map((item, i) => (
            <div className="ai-surface flex flex-col gap-2 rounded-md p-3" key={i}>
              <div className="flex items-start gap-2.5">
                <Checkbox
                  checked={item.included}
                  className="mt-0.5"
                  id={`analyze-item-${i}`}
                  onCheckedChange={() => onToggle(i)}
                />
                <label className="flex-1 text-sm" htmlFor={`analyze-item-${i}`}>
                  <span className="ai-badge mr-2">{KIND_LABEL[item.highlight.kind]}</span>
                  <span className="text-muted-foreground">“{item.highlight.text}”</span>
                  {item.highlight.kind === "learned" && (
                    <span className="ml-2 text-xs text-muted-foreground">
                      {item.highlight.category} / {item.highlight.title}
                    </span>
                  )}
                  {item.highlight.kind === "goal" && (
                    <span className="ml-2 text-xs text-muted-foreground">
                      {item.highlight.title} ({item.highlight.cadence})
                    </span>
                  )}
                </label>
              </div>
              {(item.highlight.kind === "task_new" || item.highlight.kind === "buy_new") && (
                <Input
                  className="ml-7 w-auto"
                  disabled={!item.included}
                  value={item.text}
                  onChange={(e) => onEditText(i, e.target.value)}
                />
              )}
              {item.highlight.kind === "habit" && Object.keys(item.metadata).length > 0 && (
                <div className="ml-7 flex flex-wrap gap-2">
                  {Object.entries(item.metadata).map(([key, value]) => (
                    <label className="flex flex-col gap-1 text-xs text-muted-foreground" key={key}>
                      {humanizeKey(key)}
                      <Input
                        className="w-32"
                        disabled={!item.included}
                        value={value}
                        onChange={(e) => onEditMetadata(i, key, e.target.value)}
                      />
                    </label>
                  ))}
                </div>
              )}
            </div>
          ))}
      </div>

      <div className="flex flex-wrap items-center justify-end gap-2">
        <Button size="sm" variant="ghost" onClick={onCancel}>
          Cancel
        </Button>
        <Button disabled={state.status !== "ready"} size="sm" onClick={onConfirm}>
          Apply
        </Button>
      </div>
    </div>
  );
}
