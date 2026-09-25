"use client";

import * as React from "react";
import { useRouter } from "next/navigation";

interface CapturesPollerProps {
  hasInFlight: boolean;
  intervalMs?: number;
}

// Mirrors components/assessments/eval-poller.tsx: setInterval + router.refresh()
// while any capture is still pending/processing — a timer side-effect, not
// data fetching, so useEffect is the correct tool (no server-component
// alternative for browser-side intervals). Renders nothing visible.
export function CapturesPoller({ hasInFlight, intervalMs = 5_000 }: CapturesPollerProps) {
  const router = useRouter();

  React.useEffect(() => {
    if (!hasInFlight) return;
    const id = setInterval(() => {
      // Each tick re-renders the whole RSC tree; skip it while the tab is hidden.
      if (document.visibilityState === "visible") router.refresh();
    }, intervalMs);
    return () => clearInterval(id);
  }, [hasInFlight, intervalMs, router]);

  return null;
}
