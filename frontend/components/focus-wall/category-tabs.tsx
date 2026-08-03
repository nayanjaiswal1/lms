"use client";

import { useState } from "react";
import { Pencil, X } from "lucide-react";
import { AddCategoryTab } from "@/components/focus-wall/add-category-tab";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { NOTE_CATEGORY_FILTER_OPTIONS } from "@/lib/constants";
import type { FocusCategory, FocusNote } from "@/lib/server/focus-wall";
import { cn } from "@/lib/utils";
import styles from "./focus-wall.module.css";

// Folder-tab color per built-in category, full screen only — every custom
// category takes the base kraft tone from .tab itself.
const CATEGORY_TAB_CLASS: Record<string, string> = {
  personal: styles.tabPersonal,
  study: styles.tabStudy,
  urgent: styles.tabUrgent,
};

interface PendingDeletion {
  category: FocusCategory;
  count: number;
  moveTarget: string;
}

interface CategoryTabsProps {
  categories: FocusCategory[];
  notes: FocusNote[];
  activeCategory: string;
  onSelect: (name: string) => void;
  onAdd: (name: string) => Promise<boolean>;
  onMoveNotes: (from: string, to: string) => Promise<void>;
  onDeleteNotesInCategory: (category: string) => Promise<void>;
  onRemoveCategory: (category: FocusCategory) => Promise<void>;
}

// Chrome-tab-style management: a single pencil at the end of the row toggles
// edit mode, which reveals a delete "x" on every custom tab (built-ins have
// no backing row to delete). Deleting a category that still has notes in it
// never silently drops them — it asks whether to move them elsewhere or
// delete them along with the category.
export function CategoryTabs({
  categories,
  notes,
  activeCategory,
  onSelect,
  onAdd,
  onMoveNotes,
  onDeleteNotesInCategory,
  onRemoveCategory,
}: CategoryTabsProps) {
  const [editMode, setEditMode] = useState(false);
  const [pending, setPending] = useState<PendingDeletion | null>(null);

  const otherTargets = [
    ...NOTE_CATEGORY_FILTER_OPTIONS.filter((o) => o.value !== "all"),
    ...categories.filter((c) => c.id !== pending?.category.id).map((c) => ({ label: c.name, value: c.name })),
  ];

  function requestDelete(category: FocusCategory) {
    const count = notes.filter((n) => n.category === category.name).length;
    if (count === 0) {
      void onRemoveCategory(category);
      return;
    }
    setPending({ category, count, moveTarget: otherTargets[0]?.value ?? "personal" });
  }

  async function handleMoveAndDelete() {
    if (!pending) return;
    await onMoveNotes(pending.category.name, pending.moveTarget);
    await onRemoveCategory(pending.category);
    setPending(null);
  }

  async function handleDeleteNotesAndCategory() {
    if (!pending) return;
    await onDeleteNotesInCategory(pending.category.name);
    await onRemoveCategory(pending.category);
    setPending(null);
  }

  return (
    <>
      <div className={cn("flex flex-wrap justify-center gap-1", styles.tabGroup)}>
        {NOTE_CATEGORY_FILTER_OPTIONS.map((opt) => (
          <Button
            className={cn(
              "touch-target h-auto px-4 py-2 text-xs font-bold uppercase hover:bg-transparent",
              styles.tab,
              CATEGORY_TAB_CLASS[opt.value],
            )}
            data-active={activeCategory === opt.value}
            key={opt.value}
            variant="ghost"
            onClick={() => onSelect(opt.value)}
          >
            {opt.label}
          </Button>
        ))}

        {categories.map((c) => (
          <Button
            className={cn(
              "touch-target h-auto gap-1.5 px-4 py-2 text-xs font-bold uppercase hover:bg-transparent",
              styles.tab,
            )}
            data-active={activeCategory === c.name}
            key={c.id}
            variant="ghost"
            onClick={() => onSelect(c.name)}
          >
            {c.name}
            {editMode && (
              <span
                aria-label={`Delete category ${c.name}`}
                className="-mr-1.5 rounded-full p-0.5 hover:bg-foreground/15"
                role="button"
                tabIndex={-1}
                onClick={(e) => {
                  e.stopPropagation();
                  requestDelete(c);
                }}
                onKeyDown={(e) => {
                  if (e.key !== "Enter" && e.key !== " ") return;
                  e.stopPropagation();
                  e.preventDefault();
                  requestDelete(c);
                }}
              >
                <X aria-hidden className="size-3" />
              </span>
            )}
          </Button>
        ))}

        {categories.length > 0 && (
          <Button
            aria-label={editMode ? "Done editing categories" : "Edit categories"}
            aria-pressed={editMode}
            className={cn("touch-target h-auto rounded-full px-3 py-2", editMode && "bg-accent")}
            variant="ghost"
            onClick={() => setEditMode((m) => !m)}
          >
            <Pencil aria-hidden className="size-4" />
          </Button>
        )}
        <AddCategoryTab onAdd={onAdd} />
      </div>

      <Dialog open={pending !== null} onOpenChange={(open) => !open && setPending(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete &ldquo;{pending?.category.name}&rdquo;?</DialogTitle>
            <DialogDescription>
              {pending?.count} note{pending?.count === 1 ? "" : "s"} use this category. Move them somewhere else, or
              delete them along with the category.
            </DialogDescription>
          </DialogHeader>
          <Select
            value={pending?.moveTarget}
            onValueChange={(value) => setPending((p) => (p ? { ...p, moveTarget: value } : p))}
          >
            <SelectTrigger>
              <SelectValue placeholder="Move notes to…" />
            </SelectTrigger>
            <SelectContent>
              {otherTargets.map((opt) => (
                <SelectItem key={opt.value} value={opt.value}>
                  {opt.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setPending(null)}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={handleDeleteNotesAndCategory}>
              Delete notes too
            </Button>
            <Button onClick={handleMoveAndDelete}>Move notes &amp; delete category</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
