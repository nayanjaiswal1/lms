"use client";

import { createContext, useContext, useState, type ReactNode } from "react";

interface ModuleGateContextValue {
  requiredIds: string[];
  passedIds: Set<string>;
  markPassed: (questionId: string) => void;
}

const ModuleGateContext = createContext<ModuleGateContextValue | null>(null);

export function useModuleGate(): ModuleGateContextValue {
  const ctx = useContext(ModuleGateContext);
  if (!ctx) throw new Error("useModuleGate must be used within ModuleGateProvider");
  return ctx;
}

interface ModuleGateProviderProps {
  requiredIds: string[];
  initialPassedIds: string[];
  children: ReactNode;
}

// Shares "has this lesson's embedded knowledge-check been passed" state
// between LessonKnowledgeCheck (marks a question passed on a correct submit)
// and both ModuleCompleteButton instances (mobile, inside ModuleNotes, and
// desktop, in the page's ModuleProgressRail) — they live in separate DOM
// subtrees under page.tsx, so a shared Context is needed instead of lifted
// component state. requiredIds is empty for any module without an embedded
// check, so the gate is a no-op everywhere else.
export function ModuleGateProvider({ requiredIds, initialPassedIds, children }: ModuleGateProviderProps) {
  const [passedIds, setPassedIds] = useState<Set<string>>(() => new Set(initialPassedIds));

  const markPassed = (questionId: string) => {
    setPassedIds((prev) => {
      if (prev.has(questionId)) return prev;
      const next = new Set(prev);
      next.add(questionId);
      return next;
    });
  };

  return (
    <ModuleGateContext.Provider value={{ requiredIds, passedIds, markPassed }}>
      {children}
    </ModuleGateContext.Provider>
  );
}
