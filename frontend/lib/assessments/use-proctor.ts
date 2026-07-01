"use client";

import * as React from "react";
import type { ProctoringConfig } from "@/lib/assessments/types";
import { useDevToolsDetector } from "@/lib/assessments/use-devtools-detector";

export type ProctorSeverity = "info" | "warning" | "critical";

export interface ProctorEvent {
  type: string;
  severity: ProctorSeverity;
  metadata: Record<string, unknown>;
}

interface ProctorOptions {
  config: ProctoringConfig;
  enabled: boolean;
  durationSeconds: number;
  onEvent: (event: ProctorEvent) => void;
  onTimeUp: () => void;
  onAutoSubmit?: () => void;
}

export interface ProctorState {
  secondsLeft: number;
  violations: number;
  tabSwitches: number;
  focusLosses: number;
  isFullscreen: boolean;
  /** True whenever the student is outside fullscreen while require_fullscreen is on.
   *  Drives the blocking overlay regardless of which exit action is configured. */
  isFullscreenViolation: boolean;
  devToolsOpen: boolean;
  requestFullscreen: () => void;
}

// Keys that commonly open developer tools; blocked when block_devtools is on.
function isDevtoolsCombo(e: KeyboardEvent): boolean {
  if (e.key === "F12") return true;
  const k = e.key.toLowerCase();
  if (e.ctrlKey && e.shiftKey && (k === "i" || k === "j" || k === "c")) return true;
  if (e.ctrlKey && k === "u") return true;
  return false;
}

// useProctor wires the full anti-cheat engine for an in-progress attempt:
// fullscreen enforcement, tab/focus tracking, copy/paste/right-click/devtools
// blocking, a heartbeat, and a countdown. Every signal is forwarded to onEvent
// (which persists it server-side, where the authoritative auto-submit lives).
//
// This hook is the one justified place that uses useEffect: attaching native
// window/document listeners and running interval timers has no server-component
// or hook-library equivalent.
export function useProctor(options: ProctorOptions): ProctorState {
  const { config, enabled, durationSeconds, onEvent, onTimeUp, onAutoSubmit } = options;

  const [secondsLeft, setSecondsLeft] = React.useState(durationSeconds);
  const [counts, setCounts] = React.useState({ violations: 0, tabSwitches: 0, focusLosses: 0 });
  const [isFullscreen, setIsFullscreen] = React.useState(false);
  const [isFullscreenViolation, setIsFullscreenViolation] = React.useState(false);
  // pausedRef lets the setInterval callback read the latest pause state without
  // causing the effect to re-subscribe every time the pause state changes.
  const pausedRef = React.useRef(false);
  const onAutoSubmitRef = React.useRef(onAutoSubmit ?? (() => undefined));
  onAutoSubmitRef.current = onAutoSubmit ?? (() => undefined);

  // Stable refs so the effect can read latest callbacks without re-subscribing.
  const onEventRef = React.useRef(onEvent);
  onEventRef.current = onEvent;
  const onTimeUpRef = React.useRef(onTimeUp);
  onTimeUpRef.current = onTimeUp;

  // Guard against calling setState or invoking callbacks after unmount. The
  // effect's cleanup sets this to false; every async path checks it first.
  const mountedRef = React.useRef(true);
  React.useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
    };
  }, []);

  const emit = React.useCallback((type: string, severity: ProctorSeverity, metadata: Record<string, unknown> = {}) => {
    if (!mountedRef.current) return;
    onEventRef.current({ type, severity, metadata });
    if (severity !== "info") {
      setCounts((c) => ({ ...c, violations: c.violations + 1 }));
    }
  }, []);

  const requestFullscreen = React.useCallback(() => {
    const el = document.documentElement;
    if (el.requestFullscreen) void el.requestFullscreen().catch(() => undefined);
  }, []);

  React.useEffect(() => {
    if (!enabled) return;

    const onVisibility = () => {
      if (document.hidden) {
        setCounts((c) => ({ ...c, tabSwitches: c.tabSwitches + 1, violations: c.violations + 1 }));
        emit("visibility_hidden", "warning", { hidden: true });
      } else {
        emit("visibility_visible", "info", {});
      }
    };
    const onBlur = () => {
      setCounts((c) => ({ ...c, focusLosses: c.focusLosses + 1, violations: c.violations + 1 }));
      emit("focus_loss", "warning", {});
    };
    const onFocus = () => emit("focus_gain", "info", {});
    const onFullscreen = () => {
      const fs = Boolean(document.fullscreenElement);
      setIsFullscreen(fs);
      if (!fs && config.require_fullscreen) {
        const action = config.fullscreen_exit_action || "pause";
        setIsFullscreenViolation(true);
        emit("fullscreen_exit", "critical", { action });
        if (action === "auto_submit") {
          onAutoSubmitRef.current();
        } else if (action === "pause") {
          pausedRef.current = true;
        }
        // "continue": isFullscreenViolation=true blocks the overlay; timer keeps running
      } else if (fs) {
        setIsFullscreenViolation(false);
        pausedRef.current = false;
        emit("fullscreen_enter", "info", {});
      }
    };
    const onCopy = (e: ClipboardEvent) => {
      if (!config.block_copy_paste) return;
      e.preventDefault();
      emit("copy", "warning", {});
    };
    const onCut = (e: ClipboardEvent) => {
      if (!config.block_copy_paste) return;
      e.preventDefault();
      emit("cut", "warning", {});
    };
    const onPaste = (e: ClipboardEvent) => {
      if (!config.block_copy_paste) return;
      e.preventDefault();
      emit("paste", "warning", {});
    };
    const onContextMenu = (e: MouseEvent) => {
      if (!config.block_right_click) return;
      e.preventDefault();
      emit("right_click", "info", {});
    };
    const onKeyDown = (e: KeyboardEvent) => {
      if (config.block_devtools && isDevtoolsCombo(e)) {
        e.preventDefault();
        emit("devtools_open", "warning", { key: e.key });
      }
    };
    const onOffline = () => emit("network_offline", "warning", {});

    document.addEventListener("visibilitychange", onVisibility);
    window.addEventListener("blur", onBlur);
    window.addEventListener("focus", onFocus);
    document.addEventListener("fullscreenchange", onFullscreen);
    document.addEventListener("copy", onCopy);
    document.addEventListener("cut", onCut);
    document.addEventListener("paste", onPaste);
    document.addEventListener("contextmenu", onContextMenu);
    document.addEventListener("keydown", onKeyDown);
    window.addEventListener("offline", onOffline);

    const heartbeatMs = Math.max(5, config.heartbeat_seconds || 15) * 1000;
    const heartbeat = window.setInterval(() => emit("heartbeat", "info", {}), heartbeatMs);
    const ticker = window.setInterval(() => {
      if (pausedRef.current) return;
      setSecondsLeft((s) => {
        if (s <= 1) {
          window.clearInterval(ticker);
          onTimeUpRef.current();
          return 0;
        }
        return s - 1;
      });
    }, 1000);

    return () => {
      document.removeEventListener("visibilitychange", onVisibility);
      window.removeEventListener("blur", onBlur);
      window.removeEventListener("focus", onFocus);
      document.removeEventListener("fullscreenchange", onFullscreen);
      document.removeEventListener("copy", onCopy);
      document.removeEventListener("cut", onCut);
      document.removeEventListener("paste", onPaste);
      document.removeEventListener("contextmenu", onContextMenu);
      document.removeEventListener("keydown", onKeyDown);
      window.removeEventListener("offline", onOffline);
      window.clearInterval(heartbeat);
      window.clearInterval(ticker);
      pausedRef.current = false;
      setIsFullscreenViolation(false);
    };
  }, [enabled, config, emit]);

  // Size-based DevTools detection — complements keyboard shortcut blocking above.
  // Fires an event on the first detection (false → true transition) so the server
  // can record it; does not re-fire while DevTools stays open.
  const devToolsOpen = useDevToolsDetector(enabled && config.block_devtools);
  React.useEffect(() => {
    if (devToolsOpen && enabled && config.block_devtools) {
      emit("devtools_open", "warning", { method: "size_detection" });
    }
  }, [devToolsOpen, enabled, config.block_devtools, emit]);

  return {
    secondsLeft,
    violations: counts.violations,
    tabSwitches: counts.tabSwitches,
    focusLosses: counts.focusLosses,
    isFullscreen,
    isFullscreenViolation,
    devToolsOpen,
    requestFullscreen,
  };
}
