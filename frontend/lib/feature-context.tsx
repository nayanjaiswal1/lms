"use client";

import { createContext, useContext } from "react";
import { type Feature, type LockedFeatureInfo } from "@/lib/features";

// ─────────────────────────────────────────────
// Context shape
//
// entitlements — flat set of features the user can actually USE,
//               resolved by the backend from plan + add-ons.
//               Frontend NEVER re-derives this from a plan tier.
//
// orgFeatures  — features the org has enabled (org-level toggle).
//               A feature can be in orgFeatures but not in entitlements
//               (e.g., org has wiki enabled but user's plan doesn't include it).
//
// lockedInfo   — for each feature NOT in entitlements, the backend
//               tells us HOW to unlock it (plan upgrade / add-on / both).
//               Drives lock overlay CTAs without hardcoding plan names.
// ─────────────────────────────────────────────

interface FeatureFlagContextValue {
  orgFeatures:  Set<Feature>;
  entitlements: Set<Feature>;
  lockedInfo:   Partial<Record<Feature, LockedFeatureInfo>>;
}

const FeatureFlagContext = createContext<FeatureFlagContextValue>({
  orgFeatures:  new Set(),
  entitlements: new Set(),
  lockedInfo:   {},
});

// ─────────────────────────────────────────────
// Provider — placed once in app/layout.tsx.
// Root layout (server) fetches org config + user
// entitlements, passes here as props.
// ─────────────────────────────────────────────

interface FeatureFlagProviderProps {
  orgFeatures:  Feature[];
  entitlements: Feature[];
  lockedInfo:   Partial<Record<Feature, LockedFeatureInfo>>;
  children:     React.ReactNode;
}

export function FeatureFlagProvider({
  orgFeatures,
  entitlements,
  lockedInfo,
  children,
}: FeatureFlagProviderProps) {
  return (
    <FeatureFlagContext.Provider
      value={{
        orgFeatures:  new Set(orgFeatures),
        entitlements: new Set(entitlements),
        lockedInfo,
      }}
    >
      {children}
    </FeatureFlagContext.Provider>
  );
}

// ─────────────────────────────────────────────
// Hooks — for client components only.
// Server components call lib/server/features.ts directly.
// ─────────────────────────────────────────────

/** Is this feature enabled for the org at all? */
export function useIsOrgFeatureEnabled(feature: Feature): boolean {
  return useContext(FeatureFlagContext).orgFeatures.has(feature);
}

/**
 * Does this user have an entitlement for this feature?
 * Entitlements are resolved server-side from plan + add-ons.
 * This is the primary access check — never compare plan tier directly.
 */
export function useIsEntitled(feature: Feature): boolean {
  return useContext(FeatureFlagContext).entitlements.has(feature);
}

/** How to unlock a feature the user doesn't currently have. */
export function useLockedInfo(feature: Feature): LockedFeatureInfo | undefined {
  return useContext(FeatureFlagContext).lockedInfo[feature];
}

/** Full context — use when you need multiple values. */
export function useFeatureFlags() {
  return useContext(FeatureFlagContext);
}
