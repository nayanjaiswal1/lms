"use client";

import { useState, useTransition } from "react";
import Link from "next/link";
import { AnimatePresence, motion } from "framer-motion";
import { CheckCircle2, MoreVertical, Pencil, Trash2, X } from "lucide-react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { JournalMarkdown } from "@/components/journal/journal-markdown";
import ROUTES from "@/lib/routes";
import { journalTagSwatchClass } from "@/lib/journal/tag-color";
import { cn } from "@/lib/utils";
import { deleteJournalEntryAction } from "@/app/(app)/journal/actions";
import type { JournalEntry } from "@/lib/server/journal";

interface JournalEntryCardProps {
  entry: JournalEntry;
  // Merge-select mode (see useJournalMerge) — only meaningful for
  // source: "journal" entries. When selectable, clicking the card toggles
  // selection instead of expanding it.
  selectable?: boolean;
  selected?: boolean;
  onToggleSelect?: () => void;
}

// Matches globals.css --duration-normal / --ease-smooth.
const EASE_SMOOTH = [0.22, 1, 0.36, 1] as const;

export function JournalEntryCard({ entry, selectable, selected, onToggleSelect }: JournalEntryCardProps) {
  const [expanded, setExpanded] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [isPending, startTransition] = useTransition();
  const isTask = entry.source === "task";

  function confirmDelete() {
    startTransition(async () => {
      const result = await deleteJournalEntryAction(entry.id);
      if (!result.ok) {
        toast.error(result.error ?? "Couldn't delete this entry.");
        return;
      }
      toast.success("Entry deleted.");
      setConfirmOpen(false);
    });
  }

  function openCard() {
    setExpanded(true);
  }

  function closeCard() {
    setExpanded(false);
  }

  function onCardClick() {
    if (selectable) {
      onToggleSelect?.();
      return;
    }
    if (!expanded) openCard();
  }

  // Read-only: a completed What Now? task projected onto its finished day,
  // not a real journal row — nothing to expand, edit, delete, or merge.
  if (isTask) {
    return (
      <div className="card-base flex w-full max-w-xs items-center gap-2 p-4">
        <CheckCircle2 aria-hidden className="size-4 shrink-0 text-success" />
        <div className="flex min-w-0 flex-col gap-1">
          <span className="font-mono text-xs uppercase tracking-wider text-muted-foreground">
            Task / {entry.subcategory}
          </span>
          <p className="truncate text-sm font-semibold leading-snug text-foreground">{entry.title}</p>
        </div>
      </div>
    );
  }

  return (
    <>
      {/* Controlled (not <details>) so expanding one card can grow it to the
          row's full width and animate — the other cards in the flex-wrap row
          reflow around it, native <details> can't drive that. Click only
          opens (or, in merge-select mode, toggles selection); closing is the
          dedicated button below, not another click on the (now full of
          markdown links/text) card body. */}
      <div
        aria-expanded={selectable ? undefined : expanded}
        aria-pressed={selectable ? selected : undefined}
        className={cn(
          "card-base w-full p-4 transition-[max-width] duration-normal ease-smooth",
          selectable && "cursor-pointer ring-offset-background",
          selectable && selected && "ring-2 ring-primary",
          !selectable && (expanded ? "max-w-full" : "max-w-xs cursor-pointer hover:bg-accent/50"),
          selectable && "max-w-xs",
        )}
        role={expanded && !selectable ? undefined : "button"}
        tabIndex={expanded && !selectable ? undefined : 0}
        onClick={onCardClick}
        onKeyDown={(e) => {
          if (e.key !== "Enter" && e.key !== " ") return;
          if (!selectable && expanded) return;
          e.preventDefault();
          onCardClick();
        }}
      >
        <div className="flex items-start justify-between gap-2">
          <div className={cn("flex min-w-0 flex-col", expanded ? "gap-2" : "gap-1")}>
            <span className="flex items-center gap-1.5 font-mono text-xs uppercase tracking-wider text-muted-foreground">
              <span
                aria-hidden
                className={cn("size-2 shrink-0 rounded-full", journalTagSwatchClass(entry.category, entry.subcategory))}
              />
              {entry.category} / {entry.subcategory}
            </span>
            <p className={cn("text-sm font-semibold leading-snug text-foreground", !expanded && "truncate")}>
              {entry.title}
            </p>
          </div>
          {!selectable && (
            <div className="flex shrink-0 items-center gap-1">
              {expanded && (
                <Button
                  aria-label="Collapse entry"
                  className="touch-target"
                  size="icon"
                  variant="ghost"
                  onClick={(e) => {
                    e.stopPropagation();
                    closeCard();
                  }}
                >
                  <X aria-hidden className="h-4 w-4" />
                </Button>
              )}
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button
                    aria-label={`${entry.title} options`}
                    className="touch-target"
                    size="icon"
                    variant="ghost"
                    onClick={(e) => e.stopPropagation()}
                  >
                    <MoreVertical aria-hidden className="h-4 w-4" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem asChild>
                    <Link href={ROUTES.journalEdit(entry.id)}>
                      <Pencil aria-hidden className="h-4 w-4" />
                      Edit
                    </Link>
                  </DropdownMenuItem>
                  <DropdownMenuItem
                    className="text-destructive focus:text-destructive"
                    onSelect={() => setConfirmOpen(true)}
                  >
                    <Trash2 aria-hidden className="h-4 w-4" />
                    Delete
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
          )}
        </div>
        <AnimatePresence initial={false}>
          {expanded && !selectable && (
            <motion.div
              animate={{ height: "auto", opacity: 1 }}
              className="overflow-hidden"
              exit={{ height: 0, opacity: 0 }}
              initial={{ height: 0, opacity: 0 }}
              transition={{ duration: 0.2, ease: EASE_SMOOTH }}
            >
              <div className="mt-1">
                <JournalMarkdown content={entry.content} />
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      <ConfirmDialog
        destructive
        confirmLabel="Delete"
        description="This permanently removes this entry. This can't be undone."
        open={confirmOpen}
        pending={isPending}
        title={`Delete "${entry.title}"?`}
        onConfirm={confirmDelete}
        onOpenChange={setConfirmOpen}
      />
    </>
  );
}
