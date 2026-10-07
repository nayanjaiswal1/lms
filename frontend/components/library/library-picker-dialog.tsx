"use client";

import { useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Loader2, Search } from "lucide-react";

import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Checkbox } from "@/components/ui/checkbox";
import { Label } from "@/components/ui/label";
import { cn } from "@/lib/utils";
import {
  attachLibraryItemAction,
  listLibraryItemsAction,
  previewLibraryItemAction,
  tryLibraryItemAction,
} from "@/lib/library/actions";
import type { LibraryItem, LibraryKind } from "@/lib/library/types";
import ROUTES from "@/lib/routes";

const DEBOUNCE_MS = 300;
const KIND_FILTERS: { label: string; value: LibraryKind | "all" }[] = [
  { label: "All", value: "all" },
  { label: "Labs", value: "lab" },
  { label: "Quizzes", value: "quiz" },
  { label: "Notes", value: "notes" },
];

interface LibraryPickerDialogProps {
  sectionId: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onAdded: () => void;
}

interface ListState {
  query: string;
  kind: LibraryKind | "all";
  items: LibraryItem[];
}

interface Selection {
  item: LibraryItem;
  preview: unknown;
  required: boolean;
}

/** Filters + results on the left, preview/Try/Add on the right. Position is
 * never asked here — Attach appends at the end of the section when the
 * caller omits it, which is what course-builder-menu.tsx's "Add from
 * library" always does (see docs/debug-labs.md's Part 3 implementation
 * notes for the per-slot-position deviation). */
export function LibraryPickerDialog({ sectionId, open, onOpenChange, onAdded }: LibraryPickerDialogProps) {
  const router = useRouter();
  const [list, setList] = useState<ListState>({ query: "", kind: "all", items: [] });
  const [selection, setSelection] = useState<Selection | null>(null);
  const [isSearching, startSearch] = useTransition();
  const [isPreviewing, startPreview] = useTransition();
  const [isWorking, startWork] = useTransition();
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  function runSearch(query: string, kind: LibraryKind | "all") {
    startSearch(async () => {
      const result = await listLibraryItemsAction({
        q: query.trim() || undefined,
        types: kind === "all" ? undefined : [kind],
      });
      setList((prev) => ({ ...prev, items: result.ok ? (result.data?.items ?? []) : [] }));
    });
  }

  function handleOpenChange(next: boolean) {
    onOpenChange(next);
    if (next && list.items.length === 0) runSearch(list.query, list.kind);
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
    setSelection({ item, preview: null, required: false });
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

  function handleAdd() {
    if (!selection) return;
    const { item, required } = selection;
    startWork(async () => {
      const result = await attachLibraryItemAction(sectionId, {
        kind: item.kind,
        item_id: item.id,
        is_required: item.kind === "lab" ? required : undefined,
      });
      if (!result.ok) {
        toast.error(result.error ?? "Failed to add this item.");
        return;
      }
      toast.success(`${item.title} added.`);
      onAdded();
      onOpenChange(false);
      setSelection(null);
      router.refresh();
    });
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="modal-responsive sm:max-w-3xl">
        <DialogHeader>
          <DialogTitle>Add from library</DialogTitle>
          <DialogDescription>
            Place an existing lab, quiz, or notes lesson into this section.
          </DialogDescription>
        </DialogHeader>

        <div className="grid gap-4 sm:grid-cols-[1fr_1fr]">
          <div className="flex min-w-0 flex-col gap-3">
            <div className="flex flex-col gap-2">
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
                  <Button aria-selected={list.kind === f.value}
                    className={cn(
                      "touch-target rounded-full border px-3 py-1 text-xs font-medium transition-colors",
                      list.kind === f.value
                        ? "border-primary bg-primary text-primary-foreground"
                        : "border-border text-muted-foreground hover:text-foreground",
                    )}
                    key={f.value}
                    role="tab"
                    type="button"
                    variant="unstyled"
                    onClick={() => handleKindChange(f.value)}
                  >
                    {f.label}
                  </Button>
                ))}
              </div>
            </div>

            <div className="flex max-h-[45dvh] flex-col gap-1.5 overflow-y-auto sm:max-h-[50dvh]">
              {isSearching && <p className="text-xs text-muted-foreground">Searching…</p>}
              {!isSearching && list.items.length === 0 && (
                <p className="text-xs text-muted-foreground">No items found.</p>
              )}
              {list.items.map((item) => (
                <Button className={cn(
                    "touch-target flex flex-col items-start gap-1 rounded-md border p-3 text-left transition-colors",
                    selection?.item.id === item.id
                      ? "border-primary bg-muted"
                      : "border-border hover:bg-muted/60",
                  )}
                  key={`${item.kind}-${item.id}`}
                  type="button"
                  variant="unstyled"
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
                </Button>
              ))}
            </div>
          </div>

          <div className="flex min-w-0 flex-col gap-3 rounded-lg border border-border p-4">
            {!selection && (
              <p className="text-sm text-muted-foreground">Select an item to preview it.</p>
            )}
            {selection && (
              <>
                <div className="flex flex-col gap-1">
                  <h3 className="truncate text-sm font-semibold">{selection.item.title}</h3>
                  {selection.item.description && (
                    <p className="text-xs text-muted-foreground">{selection.item.description}</p>
                  )}
                </div>

                {isPreviewing && <Loader2 aria-hidden className="h-4 w-4 animate-spin text-muted-foreground" />}
                {!isPreviewing && selection.preview !== null && (
                  <pre className="max-h-40 overflow-y-auto rounded-md bg-muted p-2 text-xs whitespace-pre-wrap">
                    {JSON.stringify(selection.preview, null, 2)}
                  </pre>
                )}

                {selection.item.kind === "lab" && (
                  <div className="flex items-center gap-2">
                    <Checkbox
                      checked={selection.required}
                      id="library-required"
                      onCheckedChange={(v) => setSelection((prev) => (prev ? { ...prev, required: v === true } : prev))}
                    />
                    <Label className="cursor-pointer font-normal text-sm" htmlFor="library-required">
                      Required to unlock the next section
                    </Label>
                  </div>
                )}

                <div className="mt-auto flex flex-wrap gap-2">
                  {selection.item.kind === "lab" && (
                    <Button
                      disabled={isWorking}
                      size="sm"
                      variant="outline"
                      onClick={() => handleTry(selection.item)}
                    >
                      Try it
                    </Button>
                  )}
                  <Button disabled={isWorking} size="sm" onClick={handleAdd}>
                    {isWorking ? "Adding…" : "Add"}
                  </Button>
                </div>
              </>
            )}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
