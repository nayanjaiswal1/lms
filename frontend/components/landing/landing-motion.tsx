"use client";

import type { ReactNode } from "react";
import { MotionConfig, motion } from "framer-motion";

const OFFSET = {
  up: { y: 20, x: 0 },
  left: { y: 0, x: -24 },
  right: { y: 0, x: 24 },
} as const;

// Wraps the whole landing page once so every Reveal/float animation below
// respects the OS-level reduced-motion setting without each call site
// having to opt in — framer-motion's own equivalent of globals.css's
// `@media (prefers-reduced-motion: reduce)` transition override.
export function LandingMotionConfig({ children }: { children: ReactNode }) {
  return <MotionConfig reducedMotion="user">{children}</MotionConfig>;
}

interface RevealProps {
  children: ReactNode;
  className?: string;
  direction?: keyof typeof OFFSET;
  delay?: number;
  id?: string;
}

// Scroll-triggered fade/slide-in, once per element. `.card-interactive`
// already owns hover lift — this only owns entrance, so the two never
// fight over transform.
export function Reveal({ children, className, direction = "up", delay = 0, id }: RevealProps) {
  const offset = OFFSET[direction];
  return (
    <motion.div
      className={className}
      id={id}
      initial={{ opacity: 0, ...offset }}
      transition={{ duration: 0.5, delay, ease: [0.16, 1, 0.3, 1] }}
      viewport={{ once: true, margin: "-80px" }}
      whileInView={{ opacity: 1, x: 0, y: 0 }}
    >
      {children}
    </motion.div>
  );
}

// Gentle continuous float for decorative glyphs — never on content or
// interactive elements, purely ambient background motion.
export function Float({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <motion.div
      animate={{ y: [0, -10, 0] }}
      className={className}
      transition={{ duration: 6, repeat: Infinity, ease: "easeInOut" }}
    >
      {children}
    </motion.div>
  );
}
