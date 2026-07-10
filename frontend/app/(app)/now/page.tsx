// What Now? — a single-question room inside the mindforge shell.
// The feature carries its own type stack (Besley / Albert Sans / Fragment
// Mono) and scene tokens, all scoped under .wn-scope in whatnow.css.

import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { Besley, Albert_Sans, Fragment_Mono } from "next/font/google";
import { WhatNowApp } from "@/components/whatnow/whatnow-app";
import { WhatNowSwitch } from "@/components/whatnow/whatnow-switch";
import { getFeatureConfig } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import "./whatnow.css";

const serif = Besley({ subsets: ["latin"], variable: "--font-wn-serif" });
const sans = Albert_Sans({ subsets: ["latin"], variable: "--font-wn-sans" });
const mono = Fragment_Mono({ subsets: ["latin"], weight: "400", variable: "--font-wn-mono" });

export const metadata: Metadata = { title: "What Now?" };

export default async function NowPage() {
  const { entitlements } = await getFeatureConfig();
  if (!entitlements.includes(FEATURES.WHAT_NOW)) notFound();

  return (
    <div className="relative">
      <div className={`${serif.variable} ${sans.variable} ${mono.variable} wn-root`}>
        <WhatNowApp />
      </div>
      {/* Rendered after wn-root, not before: .wn-scope creates its own
          stacking context for the scene background, which paints over an
          earlier sibling even when that sibling is absolutely positioned
          with z-index:auto (z-raised resolves to no-op here — see
          whatnow-switch.tsx). Later DOM order wins without relying on it. */}
      <WhatNowSwitch />
    </div>
  );
}
