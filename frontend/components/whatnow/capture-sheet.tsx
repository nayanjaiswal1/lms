"use client";

// The capture bar — one line in, chips out. Never asks a follow-up question.
// Dismissing the field (Escape, or clicking away) with text still in it submits
// rather than discards; a failed capture keeps the text and offers a retry.

import { useRef, useState } from "react";
import { whatnowApi } from "@/lib/whatnow/client";
import type { Task } from "@/lib/whatnow/types";

export function CaptureSheet({ onCaptured }: { onCaptured: (task: Task) => void }) {
  const [value, setValue] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const inFlight = useRef(false);

  async function doCapture(raw: string) {
    if (!raw || inFlight.current) return;
    inFlight.current = true;
    setBusy(true);
    setError(null);
    try {
      const task = await whatnowApi.captureTask(raw);
      setValue("");
      onCaptured(task);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Couldn't capture that");
    } finally {
      inFlight.current = false;
      setBusy(false);
    }
  }

  function submit(e: React.FormEvent) {
    e.preventDefault();
    void doCapture(value.trim());
  }

  function onKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Escape") e.currentTarget.blur();
  }

  function onBlur() {
    const raw = value.trim();
    if (raw) void doCapture(raw);
  }

  return (
    <form className="wn-capture" onSubmit={submit}>
      <input
        aria-label="Capture a task"
        className="wn-capture-input"
        disabled={busy}
        placeholder="Drop a task — “email Priya by friday 20m #work”"
        value={value}
        onBlur={onBlur}
        onChange={(e) => setValue(e.target.value)}
        onKeyDown={onKeyDown}
      />
      <button className="wn-capture-go" disabled={busy || !value.trim()} type="submit">
        {busy ? "…" : "Catch"}
      </button>
      {error && (
        <p className="wn-capture-error">
          {error}{" "}
          <button
            className="wn-capture-retry"
            type="button"
            onClick={() => void doCapture(value.trim())}
          >
            Retry
          </button>
        </p>
      )}
    </form>
  );
}
