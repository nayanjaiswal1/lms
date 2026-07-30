"use client";

import { createContext, useContext, type ReactNode } from "react";

// ponytail: layout.tsx already fetches the batch (name included) for the header —
// this context threads that name down to the one deep page (tests/[testId]) that
// needs it for its own breadcrumb, instead of re-fetching the batch there.
const BatchNameContext = createContext<string | null>(null);

export function BatchNameProvider({ name, children }: { name: string; children: ReactNode }) {
  return <BatchNameContext.Provider value={name}>{children}</BatchNameContext.Provider>;
}

export function useBatchName(): string {
  const name = useContext(BatchNameContext);
  if (name === null) {
    throw new Error("useBatchName must be used within BatchNameProvider");
  }
  return name;
}
