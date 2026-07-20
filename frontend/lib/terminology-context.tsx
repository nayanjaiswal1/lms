"use client";

import { createContext, useContext } from "react";
import { resolveTerminology, type Terminology } from "@/lib/terminology";

// ─────────────────────────────────────────────
// Provider — placed once in app/layout.tsx next to FeatureFlagProvider.
// Root layout (server) resolves the current org's org_type and passes
// it here as a prop; this context does the label lookup once per render.
// ─────────────────────────────────────────────

const TerminologyContext = createContext<Terminology>(resolveTerminology(null));

interface TerminologyProviderProps {
  orgType:  string | null;
  children: React.ReactNode;
}

export function TerminologyProvider({ orgType, children }: TerminologyProviderProps) {
  return (
    <TerminologyContext.Provider value={resolveTerminology(orgType)}>
      {children}
    </TerminologyContext.Provider>
  );
}

/** Org-flavored words for teacher/class/student — e.g. t.teacher, t.classPlural. */
export function useTerminology(): Terminology {
  return useContext(TerminologyContext);
}
