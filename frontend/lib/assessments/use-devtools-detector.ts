"use client";

import * as React from "react";

// Detects open DevTools via the window outer-vs-inner size differential.
// DevTools docked to bottom/top adds to outerHeight; docked left/right adds to
// outerWidth. The 160px threshold safely clears normal browser chrome (tab bar
// + address bar + bookmarks bar ≈ 80–120px on most setups) while catching any
// meaningfully-sized DevTools panel.
//
// This technique does NOT detect undocked (floating) DevTools. Keyboard shortcut
// blocking in use-proctor handles F12 / Ctrl+Shift+I / etc. The two together
// cover the most common paths: keyboard-triggered and menu-triggered.
//
// Justified useEffect: setInterval polling and resize event listeners have no
// server-component or hook-library equivalent.
export function useDevToolsDetector(enabled: boolean): boolean {
  const [open, setOpen] = React.useState(false);

  React.useEffect(() => {
    if (!enabled) return;

    const THRESHOLD = 160;
    const check = () => {
      const hGap = window.outerHeight - window.innerHeight;
      const wGap = window.outerWidth - window.innerWidth;
      setOpen(hGap > THRESHOLD || wGap > THRESHOLD);
    };

    check();
    const id = window.setInterval(check, 500);
    window.addEventListener("resize", check, { passive: true });

    return () => {
      window.clearInterval(id);
      window.removeEventListener("resize", check);
    };
  }, [enabled]);

  return open;
}
