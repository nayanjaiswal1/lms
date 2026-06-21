"use client";

import { type Feature } from "@/lib/features";
import { AccessGate, type GateMode } from "@/components/shared/access-gate";

/**
 * Bakes an access gate into a component permanently.
 * Define the gated version once — use it anywhere without wrapping.
 *
 * Without withFeature (manual gate at every use site — bad):
 *   <AccessGate feature={FEATURES.WIKI}><WikiCard /></AccessGate>
 *   <AccessGate feature={FEATURES.WIKI}><WikiCard /></AccessGate>
 *   <AccessGate feature={FEATURES.WIKI}><WikiCard /></AccessGate>
 *
 * With withFeature (gate defined once, transparent at use site — correct):
 *   export const WikiCard = withFeature(WikiCardBase, FEATURES.WIKI);
 *   // Usage anywhere:
 *   <WikiCard />   ← access gate is automatic, caller doesn't know or care
 *
 * Rules:
 * - Apply to components that are always tied to one feature
 * - Use mode="lock" for content blocks (default)
 * - Use mode="badge" for nav items / sidebar links
 * - Use mode="hide" for admin-only tools
 */
export function withFeature<P extends object>(
  Component: React.ComponentType<P>,
  feature: Feature,
  mode: GateMode = "lock",
) {
  function FeatureGated(props: P) {
    return (
      <AccessGate feature={feature} mode={mode}>
        <Component {...props} />
      </AccessGate>
    );
  }

  FeatureGated.displayName = `withFeature(${Component.displayName ?? Component.name ?? "Component"})`;

  return FeatureGated;
}
