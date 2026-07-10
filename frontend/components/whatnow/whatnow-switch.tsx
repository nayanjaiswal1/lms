"use client";

// The only nav surface for switching between What Now?'s two views — the
// sidebar links to /now alone; this icon is how a user reaches /plan and
// back. Absolutely positioned inside each page's own `relative` wrapper
// (not `fixed` to the viewport) — a transformed ancestor anywhere in the app
// shell would silently rebase a `fixed` element's containing block, which is
// exactly what broke click targeting on /now during manual testing.

import Link from "next/link";
import { usePathname } from "next/navigation";
import { CalendarClock, Compass } from "lucide-react";
import ROUTES from "@/lib/routes";

export function WhatNowSwitch() {
  const pathname = usePathname();
  const onPlan = pathname === ROUTES.PLAN;
  const target = onPlan ? ROUTES.NOW : ROUTES.PLAN;
  const label = onPlan ? "Switch to What Now?" : "Switch to Plan Day";
  const Icon = onPlan ? Compass : CalendarClock;

  return (
    <Link
      aria-label={label}
      className="touch-target absolute right-4 top-4 z-raised rounded-full border border-border bg-background text-foreground shadow-card transition-colors duration-fast ease-smooth hover:bg-accent sm:right-6 sm:top-6"
      href={target}
      title={label}
    >
      <Icon aria-hidden className="h-5 w-5" />
    </Link>
  );
}
