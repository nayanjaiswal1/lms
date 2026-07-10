"use client";

// Scene = the room's lighting. Dawn / day / evening follow the clock;
// focus overrides everything while a task is running.

import { useEffect, useState } from "react";

export type Scene = "dawn" | "day" | "evening" | "focus";

export function timeScene(now: Date = new Date()): Exclude<Scene, "focus"> {
  const h = now.getHours();
  if (h >= 5 && h < 11) return "dawn";
  if (h >= 11 && h < 17) return "day";
  return "evening";
}

export function useScene(focus: boolean): Scene {
  const [scene, setScene] = useState<Exclude<Scene, "focus">>(() => timeScene());

  useEffect(() => {
    const id = setInterval(() => setScene(timeScene()), 60_000);
    return () => clearInterval(id);
  }, []);

  return focus ? "focus" : scene;
}

export function sceneGreeting(scene: Scene): string {
  switch (scene) {
    case "dawn":    return "Morning. One thing at a time.";
    case "day":     return "Midday. Pick it up where it's warm.";
    case "evening": return "Evening. Land something small.";
    case "focus":   return "";
  }
}
