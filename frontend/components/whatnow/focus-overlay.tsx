"use client";

// Focus — the world extinguishes. Fixed overlay above the app shell:
// one task, a soft timer, and three honest exits (Done / Pause / Stuck).

import { useEffect, useRef, useState } from "react";
import { whatnowApi } from "@/lib/whatnow/client";
import type { BreakdownProposal, StuckReason, Task } from "@/lib/whatnow/types";

type Mode = "focus" | "pause" | "stuck" | "breakdown" | "resolution";

const STUCK_OPTIONS: { reason: StuckReason; label: string }[] = [
  { reason: "too_big",             label: "It's too big" },
  { reason: "not_sure_it_matters", label: "Not sure it matters" },
  { reason: "deadline_unreal",     label: "The deadline isn't real" },
  { reason: "cant_focus",          label: "I can't focus" },
];

function useElapsed(): string {
  const start = useRef(Date.now());
  const [, tick] = useState(0);
  useEffect(() => {
    const id = setInterval(() => tick((n) => n + 1), 1000);
    return () => clearInterval(id);
  }, []);
  const s = Math.floor((Date.now() - start.current) / 1000);
  return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
}

export function FocusOverlay({
  task,
  onExit,
}: {
  task: Task;
  /** message is surfaced as a toast by the parent; refresh=true reloads Now */
  onExit: (message: string | null) => void;
}) {
  const [mode, setMode] = useState<Mode>("focus");
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [resolution, setResolution] = useState("");
  const [proposal, setProposal] = useState<BreakdownProposal | null>(null);
  const elapsed = useElapsed();

  async function run<T>(fn: () => Promise<T>, after: (r: T) => void) {
    if (busy) return;
    setBusy(true);
    try {
      after(await fn());
    } catch (e) {
      setResolution(e instanceof Error ? e.message : "Something went sideways.");
      setMode("resolution");
    } finally {
      setBusy(false);
    }
  }

  const done = () =>
    run(
      () => whatnowApi.completeTask(task.id),
      (r) =>
        onExit(
          r.unlockedTasks.length > 0
            ? `Done. That unlocked ${r.unlockedTasks.length} thing${r.unlockedTasks.length === 1 ? "" : "s"}.`
            : "Done. Logged and off your mind.",
        ),
    );

  const pause = () =>
    run(
      () => whatnowApi.pauseTask(task.id, note.trim() || "Paused mid-flight."),
      () => onExit("Paused — your note will be waiting."),
    );

  const stuck = (reason: StuckReason) => {
    if (reason === "too_big") {
      return run(
        () => whatnowApi.proposeBreakdown(task.id),
        (p) => {
          setProposal(p);
          setMode("breakdown");
        },
      );
    }
    return run(
      () => whatnowApi.stuckTask(task.id, reason),
      (r) => {
        setResolution(r.message);
        setMode("resolution");
      },
    );
  };

  const confirmBreakdown = () => {
    if (!proposal) return;
    return run(
      () => whatnowApi.confirmBreakdown(task.id, proposal),
      (steps) => onExit(`Broken into ${steps.length} steps. First one's small on purpose.`),
    );
  };

  return (
    <div aria-label="Focus mode" aria-modal="true" className="wn-focus" role="dialog">
      <div aria-hidden="true" className="wn-focus-halo" />
      <div className="wn-focus-inner">
        <p className="wn-focus-timer">{elapsed}</p>
        <h2 className="wn-focus-title">{task.title}</h2>
        {task.trigger && mode === "focus" && <p className="wn-focus-trigger">{task.trigger}</p>}

        {mode === "focus" && (
          <div className="wn-focus-actions">
            <button className="wn-btn wn-btn-done" disabled={busy} onClick={done}>Done</button>
            <button className="wn-btn" disabled={busy} onClick={() => setMode("pause")}>Pause</button>
            <button className="wn-btn wn-btn-quiet" disabled={busy} onClick={() => setMode("stuck")}>
              I&rsquo;m stuck
            </button>
          </div>
        )}

        {mode === "pause" && (
          <div className="wn-focus-panel">
            <label className="wn-panel-label" htmlFor="wn-resume-note">
              Leave a note for future you
            </label>
            <textarea
              className="wn-panel-textarea"
              id="wn-resume-note"
              placeholder="Where you stopped, what's next…"
              ref={(el) => el?.focus()}
              rows={3}
              value={note}
              onChange={(e) => setNote(e.target.value)}
            />
            <div className="wn-focus-actions">
              <button className="wn-btn wn-btn-done" disabled={busy} onClick={pause}>Park it</button>
              <button className="wn-btn wn-btn-quiet" disabled={busy} onClick={() => setMode("focus")}>Back</button>
            </div>
          </div>
        )}

        {mode === "stuck" && (
          <div className="wn-focus-panel">
            <p className="wn-panel-label">What kind of stuck?</p>
            <div className="wn-stuck-grid">
              {STUCK_OPTIONS.map((o) => (
                <button className="wn-btn" disabled={busy} key={o.reason} onClick={() => stuck(o.reason)}>
                  {o.label}
                </button>
              ))}
            </div>
            <button className="wn-btn wn-btn-quiet" disabled={busy} onClick={() => setMode("focus")}>Back</button>
          </div>
        )}

        {mode === "breakdown" && proposal && (
          <div className="wn-focus-panel">
            <p className="wn-panel-label">Smaller pieces</p>
            <ol className="wn-steps">
              {proposal.steps.map((s) => (
                <li className="wn-step" key={s.id}>
                  <span>{s.title}</span>
                  {s.durationMin && <span className="wn-step-min">{s.durationMin}m</span>}
                </li>
              ))}
            </ol>
            <div className="wn-focus-actions">
              <button className="wn-btn wn-btn-done" disabled={busy} onClick={confirmBreakdown}>
                Replace with these
              </button>
              <button className="wn-btn wn-btn-quiet" disabled={busy} onClick={() => setMode("stuck")}>Back</button>
            </div>
          </div>
        )}

        {mode === "resolution" && (
          <div className="wn-focus-panel">
            <p className="wn-resolution">{resolution}</p>
            <button className="wn-btn wn-btn-done" onClick={() => onExit(null)}>Okay</button>
          </div>
        )}
      </div>
    </div>
  );
}
