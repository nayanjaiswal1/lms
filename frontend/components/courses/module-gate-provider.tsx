"use client";

import { createContext, useContext, useState, type ReactNode } from "react";

interface ModuleGateContextValue {
  requiredIds: string[];
  passedIds: Set<string>;
  markPassed: (questionId: string) => void;
  // Whether this lesson has an attached lab, and whether that lab's session
  // has reached "completed" — independent of the knowledge-check gate above,
  // both must clear before ModuleCompleteButton unlocks. labCompleted is
  // meaningless when labRequired is false (no lab attached).
  labRequired: boolean;
  labCompleted: boolean;
  // Whether this lesson's course requires a saved reflection before
  // ModuleCompleteButton unlocks (courses.disable_reflection === false), and
  // whether one has been saved yet. reflectionCompleted starts from the
  // server value (initialReflection non-empty) and flips true client-side
  // the moment LessonReflection's save succeeds — same pattern as
  // markPassed below, so the button unlocks without a full page refresh.
  reflectionRequired: boolean;
  reflectionCompleted: boolean;
  markReflectionSaved: () => void;
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
  labRequired?: boolean;
  labCompleted?: boolean;
  reflectionRequired?: boolean;
  initialReflectionCompleted?: boolean;
  children: ReactNode;
}

// Shares "has this lesson's embedded knowledge-check been passed" state
// between LessonKnowledgeCheck (marks a question passed on a correct submit)
// and both ModuleCompleteButton instances (mobile, inside ModuleNotes, and
// desktop, in the page's ModuleProgressRail) — they live in separate DOM
// subtrees under page.tsx, so a shared Context is needed instead of lifted
// component state. requiredIds is empty for any module without an embedded
// check, so the gate is a no-op everywhere else.
//
// labRequired/labCompleted piggyback on the same context for the attached-
// lab gate — no client-side "mark passed" action exists for it (unlike the
// knowledge check), it's just re-read from the server on every
// router.refresh() the lab start/end/complete actions already trigger.
export function ModuleGateProvider({
  requiredIds,
  initialPassedIds,
  labRequired = false,
  labCompleted = false,
  reflectionRequired = false,
  initialReflectionCompleted = false,
  children,
}: ModuleGateProviderProps) {
  const [passedIds, setPassedIds] = useState<Set<string>>(() => new Set(initialPassedIds));
  const [reflectionCompleted, setReflectionCompleted] = useState(initialReflectionCompleted);

  const markPassed = (questionId: string) => {
    setPassedIds((prev) => {
      if (prev.has(questionId)) return prev;
      const next = new Set(prev);
      next.add(questionId);
      return next;
    });
  };

  const markReflectionSaved = () => setReflectionCompleted(true);

  return (
    <ModuleGateContext.Provider
      value={{
        requiredIds,
        passedIds,
        markPassed,
        labRequired,
        labCompleted,
        reflectionRequired,
        reflectionCompleted,
        markReflectionSaved,
      }}
    >
      {children}
    </ModuleGateContext.Provider>
  );
}
