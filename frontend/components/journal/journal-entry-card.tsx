"use client";

import { useState, useTransition } from "react";
import Link from "next/link";
import { AnimatePresence, motion } from "framer-motion";
import { MoreVertical, Pencil, Trash2, X } from "lucide-react";
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
}

// Matches globals.css --duration-normal / --ease-smooth.
const EASE_SMOOTH = [0.22, 1, 0.36, 1] as const;

export function JournalEntryCard({ entry }: JournalEntryCardProps) {
  const [expanded, setExpanded] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [isPending, startTransition] = useTransition();

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

  return (
    <>
      {/* Controlled (not <details>) so expanding one card can grow it to the
          row's full width and animate — the other cards in the flex-wrap row
          reflow around it, native <details> can't drive that. Click only
          opens; closing is the dedicated button below, not another click on
          the (now full of markdown links/text) card body. */}
      <div
        aria-expanded={expanded}
        className={cn(
          "card-base w-full p-4 transition-[max-width] duration-normal ease-smooth",
          expanded ? "max-w-full" : "max-w-xs cursor-pointer hover:bg-accent/50",
        )}
        role={expanded ? undefined : "button"}
        tabIndex={expanded ? undefined : 0}
        onClick={expanded ? undefined : openCard}
        onKeyDown={
          expanded
            ? undefined
            : (e) => {
                if (e.key !== "Enter" && e.key !== " ") return;
                e.preventDefault();
                openCard();
              }
        }
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
          <div className="flex shrink-0 items-center gap-1">
            {expanded && (
              <Button aria-label="Collapse entry" className="touch-target" size="icon" variant="ghost" onClick={closeCard}>
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
        </div>
        <AnimatePresence initial={false}>
          {expanded && (
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
