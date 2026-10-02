"use client";

import * as React from "react";
import { useRouter } from "next/navigation";

interface RefreshPollerProps {
  /** Poll only while true (e.g. while a job is still in flight). */
  active: boolean;
  intervalMs?: number;
}

// Re-renders the server component tree on an interval while `active`, so a
// server-fetched page picks up background progress (evaluations, captures,
// lab builds). A timer side-effect, not data fetching, so useEffect is the
// correct tool (no server-component alternative for browser-side intervals).
// Renders nothing visible.
export function RefreshPoller({ active, intervalMs = 5_000 }: RefreshPollerProps) {
  const router = useRouter();

  React.useEffect(() => {
    if (!active) return;
    const id = setInterval(() => {
      // Each tick re-renders the whole RSC tree; skip it while the tab is hidden.
      if (document.visibilityState === "visible") router.refresh();
    }, intervalMs);
    return () => clearInterval(id);
  }, [active, intervalMs, router]);

  return null;
}
