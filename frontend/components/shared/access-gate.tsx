"use client";

import { Lock } from "lucide-react";
import Link from "next/link";
import { useIsOrgFeatureEnabled, useIsEntitled, useLockedInfo } from "@/lib/feature-context";
import { FEATURE_META, type Feature } from "@/lib/features";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";

// ─────────────────────────────────────────────
// Access gate modes
//
// lock  → show children blurred + lock overlay with upgrade/add-on CTA.
//         Use for feature sections and page content.
//
// badge → render children with an inline badge ("Pro", "Add-on", etc.).
//         Use for sidebar links and nav items.
//
// hide  → render nothing. Use for features that should not be
//         discoverable (e.g., org hasn't enabled the feature at all,
//         or role-restricted admin features).
// ─────────────────────────────────────────────

export type GateMode = "lock" | "badge" | "hide";

interface AccessGateProps {
  feature:   Feature;
  children:  React.ReactNode;
  mode?:     GateMode;
  className?: string;
}

/**
 * Single gate for all feature access control.
 *
 * Checks two things in order:
 *  1. Is the feature enabled for this org? (org toggle)
 *     → No: render nothing (feature doesn't exist for them)
 *  2. Does the user have an entitlement for this feature?
 *     Entitlements are resolved by the backend from plan + add-ons.
 *     → No: apply the chosen mode (lock / badge / hide)
 *
 * The lock overlay reads `lockedInfo` from context — the backend tells
 * us whether the path to unlock is a plan upgrade, an add-on, or both.
 * The frontend never hardcodes "upgrade to Pro" or any plan name.
 *
 * Usage:
 *   <AccessGate feature={FEATURES.INTERVIEW_BOARD}>
 *     <InterviewSection />
 *   </AccessGate>
 *
 *   <AccessGate feature={FEATURES.WIKI} mode="badge">
 *     <SidebarItem label="Wiki" />
 *   </AccessGate>
 */
export function AccessGate({ feature, children, mode = "lock", className }: AccessGateProps) {
  const orgEnabled  = useIsOrgFeatureEnabled(feature);
  const entitled    = useIsEntitled(feature);
  const lockedInfo  = useLockedInfo(feature);

  // Feature not enabled for org → always hide, no CTA
  if (!orgEnabled) return null;

  // User has entitlement → render normally
  if (entitled) return <>{children}</>;

  // Not entitled — apply mode
  if (mode === "hide") return null;

  if (mode === "badge") {
    return (
      <span className="relative inline-flex items-center gap-1.5">
        {children}
        <UnlockBadge lockedInfo={lockedInfo} />
      </span>
    );
  }

  // mode === "lock"
  return (
    <div className={cn("relative", className)}>
      {/* inert removes the blurred content from the tab order and the
          accessibility tree — without it, keyboard users tab into hidden,
          unusable controls behind the lock overlay. */}
      <div aria-hidden inert className="pointer-events-none select-none blur-sm opacity-40">
        {children}
      </div>
      <LockOverlay feature={feature} lockedInfo={lockedInfo} />
    </div>
  );
}

// ─────────────────────────────────────────────
// Lock overlay
// The CTA text comes from lockedInfo (server-driven),
// NOT from a hardcoded plan name.
// ─────────────────────────────────────────────

interface LockOverlayProps {
  feature:    Feature;
  lockedInfo: ReturnType<typeof useLockedInfo>;
}

function LockOverlay({ feature, lockedInfo }: LockOverlayProps) {
  const meta = FEATURE_META[feature];

  const reason   = lockedInfo?.reason   ?? `${meta.label} is not included in your current plan`;
  const ctaLabel = lockedInfo?.cta_label ?? "Unlock this feature";

  return (
    <div className="absolute inset-0 flex-center flex-col gap-3 rounded-lg bg-background/80 backdrop-blur-sm">
      <div className="flex-center h-10 w-10 rounded-full bg-muted">
        <Lock aria-hidden className="h-5 w-5 text-muted-foreground" />
      </div>
      <div className="text-center px-4">
        <p className="text-sm font-medium">{meta.label}</p>
        <p className="text-xs text-muted-foreground mt-0.5">{reason}</p>
      </div>
      <Button asChild size="sm">
        <Link href={`${ROUTES.BILLING}?feature=${feature}`}>{ctaLabel}</Link>
      </Button>
    </div>
  );
}

// ─────────────────────────────────────────────
// Inline badge for nav/sidebar mode
// Label also comes from lockedInfo so it can say
// "Add-on" or "Pro" or "Enterprise" as appropriate.
// ─────────────────────────────────────────────

function UnlockBadge({ lockedInfo }: { lockedInfo: ReturnType<typeof useLockedInfo> }) {
  const label = lockedInfo?.unlock_via === "addon" ? "Add-on" : "Upgrade";
  return (
    <Badge
      className="badge-info text-[10px] px-1.5 py-0 h-4 uppercase tracking-wide"
      variant="outline"
    >
      {label}
    </Badge>
  );
}
