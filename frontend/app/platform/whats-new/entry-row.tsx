"use client";

import { useState } from "react";
import { toast } from "sonner";

import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import type { WhatsNewEntry } from "@/lib/whats-new";
import { deleteWhatsNewEntryAction } from "./actions";
import { EntryFormDialog } from "./entry-form-dialog";

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric" });
}

interface EntryRowProps {
  entry: WhatsNewEntry;
}

export function EntryRow({ entry }: EntryRowProps) {
  const [pending, setPending] = useState(false);

  async function confirmDelete() {
    setPending(true);
    const result = await deleteWhatsNewEntryAction(entry.id);
    if (!result.ok) {
      toast.error(result.error ?? "Couldn't delete this entry.");
      setPending(false);
      return;
    }
    toast.success("Entry deleted.");
  }

  return (
    <div className="card-base flex items-start justify-between gap-4 p-4">
      <div className="min-w-0">
        <div className="flex items-center gap-2">
          <p className="font-medium text-foreground">{entry.title}</p>
          {!entry.published && <Badge variant="outline">Draft</Badge>}
        </div>
        <p className="mt-1 line-clamp-2 text-sm text-muted-foreground">{entry.description}</p>
        <p className="mt-2 text-xs text-muted-foreground">{formatDate(entry.published_at)}</p>
      </div>
      <div className="flex shrink-0 items-center gap-2">
        <EntryFormDialog entry={entry} />
        <AlertDialog>
          <AlertDialogTrigger asChild>
            <Button className="text-destructive hover:text-destructive" size="sm" variant="ghost">
              Delete
            </Button>
          </AlertDialogTrigger>
          <AlertDialogContent className="modal-responsive">
            <AlertDialogHeader>
              <AlertDialogTitle>Delete &quot;{entry.title}&quot;?</AlertDialogTitle>
              <AlertDialogDescription>
                This removes it from every user&apos;s sidebar panel immediately. This can&apos;t be undone.
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel disabled={pending}>Cancel</AlertDialogCancel>
              <AlertDialogAction disabled={pending} onClick={confirmDelete}>
                {pending ? "Deleting…" : "Delete"}
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      </div>
    </div>
  );
}
