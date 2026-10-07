"use client";

import { useRef, useState, useTransition } from "react";
import { toast } from "sonner";
import { Loader2, Search } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Checkbox } from "@/components/ui/checkbox";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { cn } from "@/lib/utils";
import {
  attachLibraryItemAction,
  listCoursesForPickerAction,
  listLibraryItemsAction,
  listSectionsForPickerAction,
  previewLibraryItemAction,
  tryLibraryItemAction,
  type CoursePickerOption,
  type SectionPickerOption,
} from "@/lib/library/actions";
import type { LibraryItem, LibraryItemPage, LibraryKind } from "@/lib/library/types";
import ROUTES from "@/lib/routes";

const DEBOUNCE_MS = 300;
const KIND_FILTERS: { label: string; value: LibraryKind | "all" }[] = [
  { label: "All", value: "all" },
  { label: "Labs", value: "lab" },
  { label: "Quizzes", value: "quiz" },
  { label: "Notes", value: "notes" },
];

interface AddFlow {
  courses: CoursePickerOption[];
  courseId: string;
  sections: SectionPickerOption[];
  sectionId: string;
}

interface Selection {
  item: LibraryItem;
  preview: unknown;
  required: boolean;
  addFlow: AddFlow | null;
}

interface LibraryBrowserProps {
  initialPage: LibraryItemPage;
}

/** Standalone /library page — same list/filter/preview/Try as the picker
 * dialog, plus "Add to course…" (pick course, then section) since there's
 * no section already in scope here. */
export function LibraryBrowser({ initialPage }: LibraryBrowserProps) {
  const [list, setList] = useState<{ query: string; kind: LibraryKind | "all"; items: LibraryItem[] }>({
    query: "", kind: "all", items: initialPage.items,
  });
  const [selection, setSelection] = useState<Selection | null>(null);
  const [isSearching, startSearch] = useTransition();
  const [isPreviewing, startPreview] = useTransition();
  const [isWorking, startWork] = useTransition();
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  function runSearch(query: string, kind: LibraryKind | "all") {
    startSearch(async () => {
      const result = await listLibraryItemsAction({ q: query.trim() || undefined, types: kind === "all" ? undefined : [kind] });
      setList((prev) => ({ ...prev, items: result.ok ? (result.data?.items ?? []) : [] }));
    });
  }

  function handleQueryChange(query: string) {
    setList((prev) => ({ ...prev, query }));
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => runSearch(query, list.kind), DEBOUNCE_MS);
  }

  function handleKindChange(kind: LibraryKind | "all") {
    setList((prev) => ({ ...prev, kind }));
    runSearch(list.query, kind);
  }

  function handleSelect(item: LibraryItem) {
    setSelection({ item, preview: null, required: false, addFlow: null });
    startPreview(async () => {
      const result = await previewLibraryItemAction(item.kind, item.id);
      setSelection((prev) => (prev && prev.item.id === item.id ? { ...prev, preview: result.ok ? result.data : null } : prev));
    });
  }

  function handleTry(item: LibraryItem) {
    startWork(async () => {
      const result = await tryLibraryItemAction(item.kind, item.id);
      if (!result.ok || !result.data) {
        toast.error(result.error ?? "Failed to start a try session.");
        return;
      }
      window.open(ROUTES.labSession(result.data.id), "_blank", "noopener,noreferrer");
    });
  }

  function openAddFlow() {
    setSelection((prev) => (prev ? { ...prev, addFlow: { courses: [], courseId: "", sections: [], sectionId: "" } } : prev));
    startWork(async () => {
      const result = await listCoursesForPickerAction();
      setSelection((prev) =>
        prev && prev.addFlow ? { ...prev, addFlow: { ...prev.addFlow, courses: result.ok ? (result.data ?? []) : [] } } : prev,
      );
    });
  }

  function handleCourseChange(courseId: string) {
    setSelection((prev) => (prev && prev.addFlow ? { ...prev, addFlow: { ...prev.addFlow, courseId, sectionId: "", sections: [] } } : prev));
    startWork(async () => {
      const result = await listSectionsForPickerAction(courseId);
      setSelection((prev) =>
        prev && prev.addFlow ? { ...prev, addFlow: { ...prev.addFlow, sections: result.ok ? (result.data ?? []) : [] } } : prev,
      );
    });
  }

  function handleAddToCourse() {
    if (!selection?.addFlow?.sectionId) return;
    const { item, required, addFlow } = selection;
    startWork(async () => {
      const result = await attachLibraryItemAction(addFlow.sectionId, {
        kind: item.kind,
        item_id: item.id,
        is_required: item.kind === "lab" ? required : undefined,
      });
      if (!result.ok) {
        toast.error(result.error ?? "Failed to add this item.");
        return;
      }
      toast.success(`${item.title} added.`);
      setSelection(null);
    });
  }

  return (
    <div className="grid gap-6 lg:grid-cols-[1fr_1fr]">
      <div className="flex min-w-0 flex-col gap-3">
        <div className="relative">
          <Search aria-hidden className="absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            aria-label="Search the library"
            className="pl-9"
            placeholder="Search labs, quizzes, notes…"
            value={list.query}
            onChange={(e) => handleQueryChange(e.target.value)}
          />
        </div>
        <div className="flex flex-wrap gap-1.5" role="tablist">
          {KIND_FILTERS.map((f) => (
            <button
              aria-selected={list.kind === f.value}
              className={cn(
                "touch-target rounded-full border px-3 py-1 text-xs font-medium transition-colors",
                list.kind === f.value ? "border-primary bg-primary text-primary-foreground" : "border-border text-muted-foreground hover:text-foreground",
              )}
              key={f.value}
              role="tab"
              type="button"
              onClick={() => handleKindChange(f.value)}
            >
              {f.label}
            </button>
          ))}
        </div>

        <div className="flex flex-col gap-1.5">
          {isSearching && <p className="text-xs text-muted-foreground">Searching…</p>}
          {!isSearching && list.items.length === 0 && <p className="text-xs text-muted-foreground">No items found.</p>}
          {list.items.map((item) => (
            <button
              className={cn(
                "touch-target flex flex-col items-start gap-1 rounded-md border p-3 text-left transition-colors",
                selection?.item.id === item.id ? "border-primary bg-muted" : "border-border hover:bg-muted/60",
              )}
              key={`${item.kind}-${item.id}`}
              type="button"
              onClick={() => handleSelect(item)}
            >
              <div className="flex w-full items-center gap-2">
                <span className="min-w-0 flex-1 truncate text-sm font-medium">{item.title}</span>
                <Badge className="shrink-0 capitalize" variant="outline">{item.kind}</Badge>
              </div>
              <div className="flex flex-wrap gap-1.5">
                <Badge className="text-xs capitalize" variant="secondary">{item.mode}</Badge>
                {item.platform && <Badge className="text-xs" variant="secondary">Platform</Badge>}
              </div>
            </button>
          ))}
        </div>
      </div>

      <div className="card-base flex min-w-0 flex-col gap-3">
        {!selection && <p className="text-sm text-muted-foreground">Select an item to preview it.</p>}
        {selection && (
          <>
            <div className="flex flex-col gap-1">
              <h2 className="truncate text-sm font-semibold">{selection.item.title}</h2>
              {selection.item.description && <p className="text-xs text-muted-foreground">{selection.item.description}</p>}
            </div>

            {isPreviewing && <Loader2 aria-hidden className="h-4 w-4 animate-spin text-muted-foreground" />}
            {!isPreviewing && selection.preview !== null && (
              <pre className="max-h-56 overflow-y-auto rounded-md bg-muted p-2 text-xs whitespace-pre-wrap">
                {JSON.stringify(selection.preview, null, 2)}
              </pre>
            )}

            {selection.item.kind === "lab" && (
              <div className="flex items-center gap-2">
                <Checkbox
                  checked={selection.required}
                  id="library-page-required"
                  onCheckedChange={(v) => setSelection((prev) => (prev ? { ...prev, required: v === true } : prev))}
                />
                <Label className="cursor-pointer text-sm font-normal" htmlFor="library-page-required">
                  Required to unlock the next section
                </Label>
              </div>
            )}

            <div className="flex flex-wrap gap-2">
              {selection.item.kind === "lab" && (
                <Button disabled={isWorking} size="sm" variant="outline" onClick={() => handleTry(selection.item)}>
                  Try it
                </Button>
              )}
              {!selection.addFlow && (
                <Button disabled={isWorking} size="sm" onClick={openAddFlow}>
                  Add to course…
                </Button>
              )}
            </div>

            {selection.addFlow && (
              <div className="flex flex-col gap-3 border-t border-border pt-3">
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="library-page-course">Course</Label>
                  <Select value={selection.addFlow.courseId} onValueChange={handleCourseChange}>
                    <SelectTrigger id="library-page-course"><SelectValue placeholder="Choose a course" /></SelectTrigger>
                    <SelectContent>
                      {selection.addFlow.courses.map((c) => (
                        <SelectItem key={c.id} value={c.id}>{c.title}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                {selection.addFlow.courseId && (
                  <div className="flex flex-col gap-1.5">
                    <Label htmlFor="library-page-section">Section</Label>
                    <Select
                      value={selection.addFlow.sectionId}
                      onValueChange={(sectionId) =>
                        setSelection((prev) => (prev && prev.addFlow ? { ...prev, addFlow: { ...prev.addFlow, sectionId } } : prev))
                      }
                    >
                      <SelectTrigger id="library-page-section"><SelectValue placeholder="Choose a section" /></SelectTrigger>
                      <SelectContent>
                        {selection.addFlow.sections.map((s) => (
                          <SelectItem key={s.id} value={s.id}>{s.title}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                )}
                <Button disabled={isWorking || !selection.addFlow.sectionId} size="sm" onClick={handleAddToCourse}>
                  {isWorking ? "Adding…" : "Add"}
                </Button>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
