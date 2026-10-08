"use client";

import { useRef } from "react";

/**
 * Runs a request under one Idempotency-Key per user intent: calls that overlap
 * (a fast double click, a retried server action) share the key, so the backend
 * runs the POST once; the key is dropped when the call settles, so the next
 * deliberate click gets a fresh one.
 */
export function useIdempotencyKey(): <T>(request: (key: string) => Promise<T>) => Promise<T> {
  const ref = useRef<string | null>(null);
  return async (request) => {
    const key = (ref.current ??= crypto.randomUUID());
    try {
      return await request(key);
    } finally {
      ref.current = null;
    }
  };
}
