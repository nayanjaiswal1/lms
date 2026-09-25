"use client";

// What Now? — root client component. Owns the scene, the energy dial,
// the Now answer, and the focus/shelf/toast orchestration. Lives inside
// the mindforge app shell; only Focus escapes it (fixed overlay).

import { useCallback, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { whatnowApi } from "@/lib/whatnow/client";
import type { Energy, NowResponse, Task } from "@/lib/whatnow/types";
import { useScene, sceneGreeting } from "@/components/whatnow/use-scene";
import { NowStage } from "@/components/whatnow/now-stage";
import { CaptureSheet } from "@/components/whatnow/capture-sheet";
import { FocusOverlay } from "@/components/whatnow/focus-overlay";
import { Shelf } from "@/components/whatnow/shelf";

export function WhatNowApp() {
  const [energy, setEnergy] = useState<Energy>("sharp");
  const [now, setNow] = useState<NowResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [focusTask, setFocusTask] = useState<Task | null>(null);
  const [shelfOpen, setShelfOpen] = useState(false);
  const [toast, setToast] = useState<string | null>(null);

  const scene = useScene(focusTask !== null);

  const loadNow = useCallback(
    async (e: Energy) => {
      setLoading(true);
      try {
        setNow(await whatnowApi.getNow(e));
      } catch (err) {
        setToast(err instanceof Error ? err.message : "Couldn't reach the shelf.");
      } finally {
        setLoading(false);
      }
    },
    [],
  );

  useEffect(() => {
    void loadNow(energy);
  }, [energy, loadNow]);

  useEffect(() => {
    if (!toast) return;
    const id = setTimeout(() => setToast(null), 3500);
    return () => clearTimeout(id);
  }, [toast]);

  function switchEnergy(e: Energy) {
    setEnergy(e);
    whatnowApi.putEnergy(e).catch(() => {});
  }

  function onCaptured(task: Task) {
    const chipText = task.chips?.map((c) => c.label).join(" · ");
    setToast(chipText ? `Caught — ${chipText}` : "Caught.");
    if (!now?.primary) void loadNow(energy);
  }

  function onFocusExit(message: string | null) {
    setFocusTask(null);
    if (message) setToast(message);
    void loadNow(energy);
  }

  return (
    <div className="wn-scope" data-wn-scene={scene}>
      <div className="wn-column">
        <header className="wn-head">
          <div>
            <h1 className="wn-title">What now?</h1>
            <p className="wn-greeting">{sceneGreeting(scene)}</p>
          </div>
          <div className="wn-head-controls">
            <div aria-label="Energy" className="wn-energy" role="radiogroup">
              <Button
                aria-checked={energy === "sharp"}
                role="radio"
                size="sm"
                variant={energy === "sharp" ? "default" : "ghost"}
                onClick={() => switchEnergy("sharp")}
              >
                Sharp
              </Button>
              <Button
                aria-checked={energy === "tired"}
                role="radio"
                size="sm"
                variant={energy === "tired" ? "default" : "ghost"}
                onClick={() => switchEnergy("tired")}
              >
                Tired
              </Button>
            </div>
            <Button size="sm" variant="outline" onClick={() => setShelfOpen(true)}>
              Shelf
            </Button>
          </div>
        </header>

        <NowStage loading={loading} now={now} onStart={setFocusTask} />

        <CaptureSheet onCaptured={onCaptured} />
      </div>

      {focusTask && <FocusOverlay task={focusTask} onExit={onFocusExit} />}
      {shelfOpen && (
        <Shelf onChanged={() => void loadNow(energy)} onClose={() => setShelfOpen(false)} />
      )}
      {toast && (
        <div className="wn-toast" role="status">
          {toast}
        </div>
      )}
    </div>
  );
}
