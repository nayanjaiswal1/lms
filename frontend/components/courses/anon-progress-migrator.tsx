"use client";

import { useEffect, useRef } from "react";
import { listAnonProgress, clearAnonProgress } from "@/lib/courses/anon-progress";
import { migrateAnonProgressAction } from "@/lib/courses/actions";
import type { AuthUser } from "@/lib/server/auth";

interface AnonProgressMigratorProps {
  user: AuthUser | null;
}

// Mounted once in the authenticated app shell (app/(app)/layout.tsx). The
// first time an authenticated user's session includes leftover anonymous
// progress (docs/anonymous.md — built up browsing a public course before
// logging in, see lib/courses/anon-progress.ts), this folds it into their
// real account and clears the local copy. Renders nothing; no-ops instantly
// when there's nothing pending or no one is logged in.
export function AnonProgressMigrator({ user }: AnonProgressMigratorProps) {
  const ranRef = useRef(false);

  useEffect(() => {
    if (!user || ranRef.current) return;
    ranRef.current = true;
    for (const { courseId, progress } of listAnonProgress()) {
      migrateAnonProgressAction(courseId, {
        completed_module_ids: progress.completedModuleIds,
        notes: progress.notes,
        reflections: progress.reflections,
      }).then((result) => {
        if (result.ok) clearAnonProgress(courseId);
      });
    }
  }, [user]);

  return null;
}
