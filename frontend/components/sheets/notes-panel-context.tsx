"use client";

import { createContext, useContext, useState, type ReactNode } from "react";

interface NotesPanelContextValue {
  open: boolean;
  editing: boolean;
  openPanel: () => void;
  closePanel: () => void;
  toggleEditing: () => void;
}

const NotesPanelContext = createContext<NotesPanelContextValue | null>(null);

// Lets "Edit notes" / "Hide notes" live in the sheet-settings menu in the
// header while the panel itself is owned by SheetSplitView deep in a
// sibling subtree — same coordination problem GroupExpandContext solves.
export function NotesPanelProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState({ open: false, editing: false });

  return (
    <NotesPanelContext.Provider
      value={{
        open: state.open,
        editing: state.editing,
        openPanel: () => setState((s) => ({ ...s, open: true })),
        closePanel: () => setState((s) => ({ ...s, open: false })),
        toggleEditing: () => setState((s) => ({ ...s, editing: !s.editing })),
      }}
    >
      {children}
    </NotesPanelContext.Provider>
  );
}

export function useNotesPanel(): NotesPanelContextValue {
  const ctx = useContext(NotesPanelContext);
  if (!ctx) throw new Error("useNotesPanel must be used within a NotesPanelProvider");
  return ctx;
}
