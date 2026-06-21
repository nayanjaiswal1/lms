"use client";

import * as React from "react";
import { useRouter } from "next/navigation";

interface EvalPollerProps {
  status: string;
  intervalMs?: number;
}

// EvalPoller auto-refreshes the result page while evaluation is pending.
// Uses setInterval + router.refresh() — this is a timer side-effect, not data
// fetching, so useEffect is the correct tool here (no server-component alternative
// for browser-side intervals). Renders nothing visible.
export function EvalPoller({ status, intervalMs = 15_000 }: EvalPollerProps) {
  const router = useRouter();

  React.useEffect(() => {
    if (status !== "evaluating" && status !== "submitted") return;
    const id = setInterval(() => router.refresh(), intervalMs);
    return () => clearInterval(id);
  }, [status, intervalMs, router]);

  return null;
}
