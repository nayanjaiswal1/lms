"use client";

import { useLinkStatus } from "next/link";
import { motion } from "framer-motion";
import { cn } from "@/lib/utils";

interface Props {
  className?: string;
}

// Must render as a child of <Link> — useLinkStatus reads pending state from
// the nearest ancestor Link's context. Next.js's own useLinkStatus guidance
// favors a subtle, fixed-size, always-mounted hint (opacity-only, never
// conditionally rendered) over a spinner — a spinner reads as "something is
// wrong," a calm pulse reads as "hang on." Delayed 100ms so a fast,
// already-prefetched navigation — the common case — never flashes it at all;
// only a genuinely slow transition earns the pulse. Ease-out on the way out
// (immediate, feels fast), ease-in-out for the breathing loop itself.
export function NavLinkHint({ className }: Props) {
  const { pending } = useLinkStatus();
  return (
    <motion.span
      aria-hidden
      animate={{ opacity: pending ? [0.3, 1] : 0 }}
      className={cn("inline-block h-1.5 w-1.5 shrink-0 rounded-full bg-current", className)}
      transition={
        pending
          ? { duration: 0.9, repeat: Infinity, repeatType: "reverse", ease: "easeInOut", delay: 0.1 }
          : { duration: 0.15, ease: "easeOut" }
      }
    />
  );
}
