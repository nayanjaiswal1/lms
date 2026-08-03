"use client";

import { useEffect, useState, type RefObject } from "react";

// Isolated so FocusWallCanvas itself never needs a useEffect or a third
// useState — the Fullscreen API's fullscreenchange event (fired on Esc, F11,
// etc.) has no server-component/use()/URL-state equivalent, so a small
// subscribing hook is the escape hatch for this one browser-only concern.
export function useFullscreen(ref: RefObject<HTMLElement | null>) {
  const [isFullscreen, setIsFullscreen] = useState(false);

  useEffect(() => {
    function handleChange() {
      setIsFullscreen(document.fullscreenElement === ref.current);
    }
    document.addEventListener("fullscreenchange", handleChange);
    return () => document.removeEventListener("fullscreenchange", handleChange);
  }, [ref]);

  function toggle() {
    if (document.fullscreenElement) {
      void document.exitFullscreen();
    } else {
      void ref.current?.requestFullscreen();
    }
  }

  return { isFullscreen, toggle };
}
