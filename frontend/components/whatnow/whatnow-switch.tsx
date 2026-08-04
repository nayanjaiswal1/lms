"use client";

// The only nav surface for switching between What Now?'s two views — the
// sidebar links to /now alone; this icon is how a user reaches /plan and
// back. Also carries the Focus Wall and Habits shortcuts, since neither has
// a sidebar entry of its own. Absolutely positioned inside each page's own
// `relative` wrapper (not `fixed` to the viewport) — a transformed ancestor
// anywhere in the app shell would silently rebase a `fixed` element's
// containing block, which is exactly what broke click targeting on /now
// during manual testing.

import Link from "next/link";
import { usePathname } from "next/navigation";
import { CalendarClock, Compass, Repeat, StickyNote, type LucideIcon } from "lucide-react";
import ROUTES from "@/lib/routes";

function SwitchIconLink({ href, icon: Icon, label }: { href: string; icon: LucideIcon; label: string }) {
  return (
    <Link
      aria-label={label}
      className="touch-target rounded-full border border-border bg-background text-foreground shadow-card transition-colors duration-fast ease-smooth hover:bg-accent"
      href={href}
      title={label}
    >
      <Icon aria-hidden className="h-5 w-5" />
    </Link>
  );
}

export function WhatNowSwitch() {
  const pathname = usePathname();
  const onPlan = pathname === ROUTES.PLAN;
  const target = onPlan ? ROUTES.NOW : ROUTES.PLAN;
  const label = onPlan ? "Switch to What Now?" : "Switch to Plan Day";
  const Icon = onPlan ? Compass : CalendarClock;

  return (
    <div className="absolute right-4 top-4 z-raised flex items-center gap-2 sm:right-6 sm:top-6">
      <SwitchIconLink href={ROUTES.HABITS} icon={Repeat} label="Open Habits" />
      <SwitchIconLink href={ROUTES.FOCUS_WALL} icon={StickyNote} label="Open Focus Wall" />
      <SwitchIconLink href={target} icon={Icon} label={label} />
    </div>
  );
}
