"use client";

import { useCallback, useEffect, useReducer } from "react";
import type { Step, TraceResult } from "@/lib/algo-visualizer/core/types";

interface VisualizerState {
  steps: Step[];
  output: string;
  outputLines: string[];
  error: string | null;
  currentIndex: number;
  playing: boolean;
  speedMs: number;
  runId: number;
}

type Action =
  | ({ type: "LOAD" } & TraceResult)
  | { type: "FIRST" }
  | { type: "PREV" }
  | { type: "NEXT" }
  | { type: "LAST" }
  | { type: "SEEK"; index: number }
  | { type: "TOGGLE_PLAY" }
  | { type: "PAUSE" }
  | { type: "SET_SPEED"; speedMs: number };

const DEFAULT_SPEED_MS = 600;

// Monaco's real input target isn't consistently e.target across browsers/CDP-driven
// input, so this checks tag/contentEditable AND walks up for the editor's own
// container rather than trusting a single element reference.
function isEditableTarget(node: EventTarget | null): boolean {
  if (!(node instanceof HTMLElement)) return false;
  if (node.tagName === "INPUT" || node.tagName === "TEXTAREA" || node.isContentEditable) return true;
  return node.closest(".monaco-editor") !== null;
}

function reducer(state: VisualizerState, action: Action): VisualizerState {
  switch (action.type) {
    case "LOAD":
      return {
        steps: action.steps,
        output: action.output,
        outputLines: action.outputLines,
        error: action.error,
        currentIndex: 0,
        playing: false,
        speedMs: state.speedMs,
        runId: state.runId + 1,
      };
    case "FIRST":
      return { ...state, currentIndex: 0, playing: false };
    case "PREV":
      return { ...state, currentIndex: Math.max(0, state.currentIndex - 1), playing: false };
    case "NEXT": {
      const next = state.currentIndex + 1;
      if (next >= state.steps.length) return { ...state, playing: false };
      return { ...state, currentIndex: next };
    }
    case "LAST":
      return { ...state, currentIndex: Math.max(0, state.steps.length - 1), playing: false };
    case "SEEK":
      return { ...state, currentIndex: Math.min(Math.max(0, action.index), Math.max(0, state.steps.length - 1)), playing: false };
    case "TOGGLE_PLAY": {
      if (state.steps.length === 0) return state;
      if (!state.playing && state.currentIndex >= state.steps.length - 1) {
        return { ...state, playing: true, currentIndex: 0 };
      }
      return { ...state, playing: !state.playing };
    }
    case "PAUSE":
      return { ...state, playing: false };
    case "SET_SPEED":
      return { ...state, speedMs: action.speedMs };
  }
}

// Playback and keyboard shortcuts are inherently browser-API concerns, not
// data fetching, so useEffect here doesn't trip the fetch-in-useEffect lint rule.
export function useVisualizerState() {
  const [state, dispatch] = useReducer(reducer, {
    steps: [],
    output: "",
    outputLines: [],
    error: null,
    currentIndex: 0,
    playing: false,
    speedMs: DEFAULT_SPEED_MS,
    runId: 0,
  });

  useEffect(() => {
    if (!state.playing) return;
    if (state.currentIndex >= state.steps.length - 1) {
      dispatch({ type: "PAUSE" });
      return;
    }
    const id = setTimeout(() => dispatch({ type: "NEXT" }), state.speedMs);
    return () => clearTimeout(id);
  }, [state.playing, state.currentIndex, state.speedMs, state.steps.length]);

  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      if (isEditableTarget(e.target) || isEditableTarget(document.activeElement)) return;
      if (e.key === "ArrowRight") {
        e.preventDefault();
        dispatch({ type: "NEXT" });
      } else if (e.key === "ArrowLeft") {
        e.preventDefault();
        dispatch({ type: "PREV" });
      } else if (e.code === "Space") {
        e.preventDefault();
        dispatch({ type: "TOGGLE_PLAY" });
      }
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  const load = useCallback((trace: TraceResult) => {
    dispatch({ type: "LOAD", ...trace });
  }, []);

  return {
    state,
    load,
    first: () => dispatch({ type: "FIRST" }),
    prev: () => dispatch({ type: "PREV" }),
    next: () => dispatch({ type: "NEXT" }),
    last: () => dispatch({ type: "LAST" }),
    seek: (index: number) => dispatch({ type: "SEEK", index }),
    togglePlay: () => dispatch({ type: "TOGGLE_PLAY" }),
    setSpeed: (speedMs: number) => dispatch({ type: "SET_SPEED", speedMs }),
  };
}

export type VisualizerActions = ReturnType<typeof useVisualizerState>;
