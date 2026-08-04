"use client";

import { createContext, useContext } from "react";

// ─────────────────────────────────────────────
// Provider — placed once in app/layout.tsx next to TerminologyProvider.
// Root layout (server) resolves the current org's name/logo override and
// passes it here as props; BrandMark (and anything else showing the
// product's identity) reads it through useBranding instead of hardcoding
// "MindForge".
// ─────────────────────────────────────────────

export interface Branding {
  name: string;
  logoUrl: string | null;
}

const DEFAULT_BRANDING: Branding = { name: "MindForge", logoUrl: null };

const BrandingContext = createContext<Branding>(DEFAULT_BRANDING);

interface BrandingProviderProps {
  name: string | null;
  logoUrl: string | null;
  children: React.ReactNode;
}

export function BrandingProvider({ name, logoUrl, children }: BrandingProviderProps) {
  const value: Branding = { name: name || DEFAULT_BRANDING.name, logoUrl };
  return <BrandingContext.Provider value={value}>{children}</BrandingContext.Provider>;
}

/** Org-overridden product name/logo, falling back to the MindForge defaults. */
export function useBranding(): Branding {
  return useContext(BrandingContext);
}
