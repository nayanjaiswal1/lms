"use client";

import type { ReactNode } from "react";
import { MotionConfig } from "framer-motion";

// Wraps the whole app once so every framer-motion usage (nav-link-hint,
// journal cards/timeline, etc.) respects the OS-level reduced-motion setting
// without each call site having to opt in — framer-motion's own equivalent
// of globals.css's `@media (prefers-reduced-motion: reduce)` transition
// override, which only ever applied to CSS animations, not framer-motion's
// JS-driven `animate` prop. Same pattern as landing-motion.tsx's
// LandingMotionConfig, hoisted to the root so new usages are covered by
// default instead of each needing its own wrapper.
export function AppMotionConfig({ children }: { children: ReactNode }) {
  return <MotionConfig reducedMotion="user">{children}</MotionConfig>;
}
