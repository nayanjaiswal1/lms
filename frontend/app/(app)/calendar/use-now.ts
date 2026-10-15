"use client";

import { useSyncExternalStore } from "react";

const MINUTE_MS = 60_000;

let cached: Date | null = null;

function subscribe(listener: () => void): () => void {
  const id = setInterval(listener, MINUTE_MS / 2);
  return () => clearInterval(id);
}

// Same Date instance for the whole minute so useSyncExternalStore sees a
// stable snapshot and only re-renders when the minute actually rolls over.
function getSnapshot(): Date {
  const minute = Math.floor(Date.now() / MINUTE_MS);
  if (!cached || Math.floor(cached.getTime() / MINUTE_MS) !== minute) cached = new Date(minute * MINUTE_MS);
  return cached;
}

/** Current time, minute precision, ticking live. null during SSR/hydration so
 * "today" and the now-line never mismatch the server-rendered markup. */
export function useNow(): Date | null {
  return useSyncExternalStore(subscribe, getSnapshot, () => null);
}
