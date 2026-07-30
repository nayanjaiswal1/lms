"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { useQueryState, parseAsStringLiteral } from "nuqs";
import { toast } from "sonner";
import {
  Search, FileQuestion, Loader2, ListChecks, Code2, PenLine, Tag, GripVertical, Plus, Trash2, Settings, type LucideIcon,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuCheckboxItem,
} from "@/components/ui/dropdown-menu";
import { addAssessmentQuestionAction, removeAssessmentQuestionAction } from "@/app/(app)/assessments/actions";
import { useCardFieldsSettings } from "@/hooks/use-card-fields-settings";
import { CARD_FIELD_LABELS, type CardFieldKey } from "@/lib/assessments/card-fields-settings";
import { QUESTION_TYPE_OPTIONS, ASSESSMENT_DIFFICULTY_OPTIONS } from "@/lib/constants";
import type { Assessment, Question } from "@/lib/assessments/types";
import type { AssessmentQuestionFull } from "@/lib/assessments/server";

const DEBOUNCE_MS = 300;

// Keeps the menu open across toggles (VS Code settings behavior), same as
// components/labs/editor-settings-menu.tsx.
const keepOpen = (e: Event) => e.preventDefault();
const CARD_FIELD_KEYS = Object.keys(CARD_FIELD_LABELS) as CardFieldKey[];

const ALL_FILTER = "all";
// Type/difficulty options mirror the same server-driven constants used
// across the question bank (lib/constants.ts) — they're fixed backend
// enums. Tags are free-form per question, so their options come from the
// live org tag list (the `tags` prop, fetched server-side) instead.
const TYPE_FILTER_OPTIONS = [{ label: "All types", value: ALL_FILTER }, ...QUESTION_TYPE_OPTIONS];
const TYPE_FILTER_VALUES = TYPE_FILTER_OPTIONS.map((o) => o.value) as [string, ...string[]];
const DIFFICULTY_FILTER_OPTIONS = [{ label: "All difficulties", value: ALL_FILTER }, ...ASSESSMENT_DIFFICULTY_OPTIONS];

// Same type→icon mapping as components/assessments/section-sidebar.tsx.
const TYPE_ICONS: Record<Question["type"], LucideIcon> = {
  mcq: ListChecks,
  coding: Code2,
  subjective: PenLine,
};

// Native HTML5 drag-and-drop payload — plain question id, no library needed
// for a same-page two-column transfer.
const DND_TYPE = "application/x-question-id";

interface QuestionsPanelProps {
  assessment: Assessment;
  attached: AssessmentQuestionFull[];
  bank: Question[];
  tags: string[];
}

// Returns null when there's no prompt worth previewing separately from the
// title — including when a question was authored with the full question
// text as its title, which would otherwise render the same text twice.
function getPrompt(content: unknown, title: string): string | null {
  if (typeof content !== "object" || content === null || !("prompt" in content)) return null;
  const prompt = (content as Record<string, unknown>).prompt;
  if (typeof prompt !== "string") return null;
  return prompt.trim().toLowerCase() === title.trim().toLowerCase() ? null : prompt;
}

// attached and bank arrive pre-filtered, pre-searched, and pre-ordered by
// the API (see page.tsx) — this component never re-filters or re-sorts them
// client-side. Every control here just updates the URL; the server round
// trip does the actual work.
export function QuestionsPanel({ assessment, attached, bank, tags }: QuestionsPanelProps) {
  const router = useRouter();
  const [isPending, startTransition] = React.useTransition();
  const [busyId, setBusyId] = React.useState<string | null>(null);
  const [dragOver, setDragOver] = React.useState<"attached" | "bank" | null>(null);
  const [attachedQuery, setAttachedQuery] = useQueryState("test_q", {
    defaultValue: "", shallow: false, throttleMs: DEBOUNCE_MS, startTransition,
  });
  const [bankQuery, setBankQuery] = useQueryState("bank_q", {
    defaultValue: "", shallow: false, throttleMs: DEBOUNCE_MS, startTransition,
  });
  const [typeFilter, setTypeFilter] = useQueryState(
    "type",
    parseAsStringLiteral(TYPE_FILTER_VALUES).withDefault(ALL_FILTER).withOptions({ shallow: false, startTransition }),
  );
  const [difficultyFilter, setDifficultyFilter] = useQueryState("difficulty", {
    defaultValue: ALL_FILTER, shallow: false, startTransition,
  });
  const [tagFilter, setTagFilter] = useQueryState("tag", { defaultValue: ALL_FILTER, shallow: false, startTransition });
  const { settings: fields, toggle: toggleField } = useCardFieldsSettings();

  // One search box drives both lists — they're disjoint (bank excludes
  // attached questions), so a term filters "am I already testing this" and
  // "what else could I add" at once instead of duplicating the input twice.
  const setQuery = (v: string) => {
    void setAttachedQuery(v);
    void setBankQuery(v);
  };

  const isDraft = assessment.status === "draft";
  const attachedIds = new Set(attached.map((q) => q.question_id));
  const tagFilterOptions = [{ label: "All tags", value: ALL_FILTER }, ...tags.map((t) => ({ label: t, value: t }))];
  const filtersActive =
    typeFilter !== ALL_FILTER || difficultyFilter !== ALL_FILTER || tagFilter !== ALL_FILTER;

  const addQuestion = async (questionId: string) => {
    setBusyId(questionId);
    const res = await addAssessmentQuestionAction(assessment.id, questionId);
    setBusyId(null);
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success("Question added.");
    router.refresh();
  };

  const removeQuestion = async (assessmentQuestionId: string, questionId: string) => {
    setBusyId(questionId);
    const res = await removeAssessmentQuestionAction(assessment.id, assessmentQuestionId);
    setBusyId(null);
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success("Question removed.");
    router.refresh();
  };

  const onDropToAttached = (e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(null);
    if (!isDraft || busyId !== null) return;
    const id = e.dataTransfer.getData(DND_TYPE);
    if (!id || attachedIds.has(id)) return;
    void addQuestion(id);
  };

  const onDropToBank = (e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(null);
    if (!isDraft || busyId !== null) return;
    const id = e.dataTransfer.getData(DND_TYPE);
    const aq = attached.find((a) => a.question_id === id);
    if (!aq) return;
    void removeQuestion(aq.id, id);
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap items-center gap-2">
          <div className="relative">
            <Search aria-hidden className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              aria-label="Search questions"
              className="h-9 w-full pl-9 sm:w-56"
              placeholder="Search questions…"
              type="search"
              value={attachedQuery}
              onChange={(e) => setQuery(e.target.value)}
            />
          </div>
          <Select value={typeFilter} onValueChange={(v) => void setTypeFilter(v)}>
            <SelectTrigger aria-label="Filter by type" className="h-9 w-36">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {TYPE_FILTER_OPTIONS.map((o) => (
                <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Select value={difficultyFilter} onValueChange={(v) => void setDifficultyFilter(v)}>
            <SelectTrigger aria-label="Filter by difficulty" className="h-9 w-40">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {DIFFICULTY_FILTER_OPTIONS.map((o) => (
                <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Select value={tagFilter} onValueChange={(v) => void setTagFilter(v)}>
            <SelectTrigger aria-label="Filter by tag" className="h-9 w-36">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {tagFilterOptions.map((o) => (
                <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
              ))}
            </SelectContent>
          </Select>
          {isPending && <Loader2 aria-hidden className="h-4 w-4 animate-spin text-muted-foreground" />}
        </div>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button aria-label="Configure question card fields" className="gap-1.5" size="sm" variant="outline">
              <Settings aria-hidden className="h-3.5 w-3.5" />
              Card fields
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuLabel>Show on each card</DropdownMenuLabel>
            {CARD_FIELD_KEYS.map((key) => (
              <DropdownMenuCheckboxItem
                checked={fields[key]}
                key={key}
                onCheckedChange={(checked) => toggleField(key, checked === true)}
                onSelect={keepOpen}
              >
                {CARD_FIELD_LABELS[key]}
              </DropdownMenuCheckboxItem>
            ))}
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      <div className="grid gap-8 lg:grid-cols-2">
        <section className="flex min-w-0 flex-col gap-3">
          <div className="flex items-center justify-between gap-3">
            <h2 className="section-title">In this test</h2>
            <span className="text-sm text-muted-foreground">{attached.length}</span>
          </div>

          <div
            className={`flex min-h-24 max-h-[36rem] flex-col gap-2 overflow-y-auto rounded-[--radius-lg] p-1 transition-colors ${dragOver === "attached" ? "ring-2 ring-primary/50" : ""}`}
            onDragLeave={() => setDragOver(null)}
            onDragOver={(e) => {
              if (!isDraft) return;
              e.preventDefault();
              setDragOver("attached");
            }}
            onDrop={onDropToAttached}
          >
            {attached.length === 0 ? (
              <div className="empty-state">
                <FileQuestion aria-hidden className="empty-state-icon" />
                <p className="font-medium">{attachedQuery.trim() || filtersActive ? "No matches" : "No questions yet"}</p>
                <p className="text-sm">
                  {attachedQuery.trim() || filtersActive
                    ? "Try a different search or filter."
                    : isDraft ? "Drag questions here from your bank, or use the + button." : "Add some from your bank on the right."}
                </p>
              </div>
            ) : (
              attached.map((q) => {
                const TypeIcon = TYPE_ICONS[q.type];
                const prompt = getPrompt(q.content, q.title);
                return (
                  <div
                    className="card-base flex items-start gap-2 p-4"
                    draggable={isDraft && busyId === null}
                    key={q.id}
                    onDragStart={(e) => e.dataTransfer.setData(DND_TYPE, q.question_id)}
                  >
                    {isDraft && (
                      <GripVertical aria-hidden className="mt-0.5 h-5 w-5 shrink-0 cursor-grab text-muted-foreground active:cursor-grabbing" />
                    )}
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium">{q.title}</p>
                      {fields.prompt && prompt && <p className="mt-1 line-clamp-2 text-sm text-muted-foreground">{prompt}</p>}
                      {(fields.type || fields.difficulty || fields.points) && (
                        <div className="mt-2 flex flex-wrap items-center gap-2">
                          {fields.type && (
                            <span className="flex items-center gap-1 text-xs text-muted-foreground capitalize">
                              <TypeIcon aria-hidden className="h-3.5 w-3.5" />
                              {q.type}
                            </span>
                          )}
                          {fields.difficulty && (
                            <span className={`difficulty-${q.difficulty} rounded-full border px-2 py-0.5 text-xs capitalize`}>
                              {q.difficulty}
                            </span>
                          )}
                          {fields.points && <span className="text-xs text-muted-foreground">{q.points} pts</span>}
                        </div>
                      )}
                      {fields.tags && q.tags.length > 0 && (
                        <div className="mt-2 flex flex-wrap items-center gap-1.5">
                          <Tag aria-hidden className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
                          {q.tags.map((tag) => (
                            <Badge className="text-xs" key={tag} variant="outline">{tag}</Badge>
                          ))}
                        </div>
                      )}
                    </div>
                    {isDraft && (
                      <Button
                        aria-label={`Remove ${q.title}`}
                        className="touch-target shrink-0"
                        disabled={busyId !== null}
                        size="icon"
                        variant="ghost"
                        onClick={() => void removeQuestion(q.id, q.question_id)}
                      >
                        {busyId === q.question_id ? <Loader2 aria-hidden className="animate-spin" /> : <Trash2 aria-hidden />}
                      </Button>
                    )}
                  </div>
                );
              })
            )}
          </div>
        </section>

        <section className="flex min-w-0 flex-col gap-3">
          <h2 className="section-title">Question bank</h2>

          {!isDraft ? (
            <p className="text-sm text-muted-foreground">Publish locks the question set. Move back to draft to edit.</p>
          ) : (
            <>
              <div
                className={`flex min-h-24 max-h-[36rem] flex-col gap-2 overflow-y-auto rounded-[--radius-lg] p-1 transition-colors ${dragOver === "bank" ? "ring-2 ring-primary/50" : ""}`}
                onDragLeave={() => setDragOver(null)}
                onDragOver={(e) => {
                  e.preventDefault();
                  setDragOver("bank");
                }}
                onDrop={onDropToBank}
              >
                {bank.length === 0 ? (
                  <div className="empty-state">
                    <FileQuestion aria-hidden className="empty-state-icon" />
                    <p className="font-medium">
                      {bankQuery.trim() || filtersActive ? "No matches" : "All bank questions are already added"}
                    </p>
                    {(bankQuery.trim() || filtersActive) && <p className="text-sm">Try a different search or filter.</p>}
                  </div>
                ) : (
                  bank.map((q) => {
                    const TypeIcon = TYPE_ICONS[q.type];
                    const prompt = getPrompt(q.content, q.title);
                    return (
                      <div
                        className="card-base flex items-start gap-2 p-3"
                        draggable={busyId === null}
                        key={q.id}
                        onDragStart={(e) => e.dataTransfer.setData(DND_TYPE, q.id)}
                      >
                        <GripVertical aria-hidden className="mt-0.5 h-5 w-5 shrink-0 cursor-grab text-muted-foreground active:cursor-grabbing" />
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-sm">{q.title}</p>
                          {fields.prompt && prompt && <p className="mt-1 line-clamp-2 text-sm text-muted-foreground">{prompt}</p>}
                          {(fields.type || fields.difficulty || fields.points) && (
                            <div className="mt-2 flex flex-wrap items-center gap-2">
                              {fields.type && (
                                <span className="flex items-center gap-1 text-xs text-muted-foreground capitalize">
                                  <TypeIcon aria-hidden className="h-3.5 w-3.5" />
                                  {q.type}
                                </span>
                              )}
                              {fields.difficulty && (
                                <span className={`difficulty-${q.difficulty} rounded-full border px-2 py-0.5 text-xs capitalize`}>
                                  {q.difficulty}
                                </span>
                              )}
                              {fields.points && <span className="text-xs text-muted-foreground">{q.default_points} pts</span>}
                            </div>
                          )}
                          {fields.tags && q.tags.length > 0 && (
                            <div className="mt-2 flex flex-wrap items-center gap-1.5">
                              <Tag aria-hidden className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
                              {q.tags.map((tag) => (
                                <Badge className="text-xs" key={tag} variant="outline">{tag}</Badge>
                              ))}
                            </div>
                          )}
                        </div>
                        <Button
                          aria-label={`Add ${q.title}`}
                          className="touch-target shrink-0"
                          disabled={busyId !== null}
                          size="icon"
                          variant="ghost"
                          onClick={() => void addQuestion(q.id)}
                        >
                          {busyId === q.id ? <Loader2 aria-hidden className="animate-spin" /> : <Plus aria-hidden />}
                        </Button>
                      </div>
                    );
                  })
                )}
              </div>
            </>
          )}
        </section>
      </div>
    </div>
  );
}
