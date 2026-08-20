"use client";

import { useState, useTransition } from "react";

import { structureJournalEntryAction } from "@/app/(app)/journal/actions";
import type { StructureJournalEntryResult } from "@/lib/server/journal";

// Ignores accidental short input (a word, a link) — only a real note-sized
// chunk of text is worth an AI call. Shared by JournalPasteCapture (paste)
// and JournalQuickAdd (typed then blurred).
export const MIN_STRUCTURE_LENGTH = 20;

interface JournalStructureState {
  open: boolean;
  draft: StructureJournalEntryResult | null;
  error: string | null;
}

const CLOSED: JournalStructureState = { open: false, draft: null, error: null };

// Shared "call AI structure -> open floating panel -> prefill the entry
// form" flow: nothing saves until the user reviews the still-fully-editable
// prefilled JournalEntryForm and hits Save.
export function useJournalStructure() {
  const [state, setState] = useState<JournalStructureState>(CLOSED);
  const [isPending, startTransition] = useTransition();

  function structure(text: string) {
    setState({ open: true, draft: null, error: null });
    startTransition(async () => {
      const result = await structureJournalEntryAction(text);
      if (!result.ok || !result.data) {
        setState({ open: true, draft: null, error: result.error ?? "Couldn't structure this with AI." });
        return;
      }
      setState({ open: true, draft: result.data, error: null });
    });
  }

  function close() {
    setState(CLOSED);
  }

  return { ...state, isPending, structure, close };
}
