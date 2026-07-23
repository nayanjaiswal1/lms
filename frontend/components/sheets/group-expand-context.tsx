"use client";

import { createContext, useContext, useRef, useState, type ReactNode } from "react";

type GroupExpandSignal = { type: "expand" | "collapse"; id: number } | null;

interface GroupExpandContextValue {
  signal: GroupExpandSignal;
  expandAll: () => void;
  collapseAll: () => void;
}

const GroupExpandContext = createContext<GroupExpandContextValue | null>(null);

// Lets the "Expand all / Collapse all" controls live in the sheet toolbar
// while the accordion state stays owned by SheetItemGroups deep in a
// sibling subtree — a context is the direct fix for two disjoint parts of
// the tree needing to coordinate one shared action.
export function GroupExpandProvider({ children }: { children: ReactNode }) {
  const [signal, setSignal] = useState<GroupExpandSignal>(null);
  const nextId = useRef(0);

  return (
    <GroupExpandContext.Provider
      value={{
        signal,
        expandAll: () => setSignal({ type: "expand", id: ++nextId.current }),
        collapseAll: () => setSignal({ type: "collapse", id: ++nextId.current }),
      }}
    >
      {children}
    </GroupExpandContext.Provider>
  );
}

export function useGroupExpandSignal(): GroupExpandContextValue {
  const ctx = useContext(GroupExpandContext);
  if (!ctx) throw new Error("useGroupExpandSignal must be used within a GroupExpandProvider");
  return ctx;
}
