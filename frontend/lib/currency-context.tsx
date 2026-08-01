"use client";

import { createContext, useContext } from "react";
import { formatMoney } from "@/lib/money";

// ─────────────────────────────────────────────
// Provider — placed once in app/layout.tsx next to TerminologyProvider.
// Root layout (server) resolves the deployment's PAYMENTS_CURRENCY and passes
// it here, so no client component has to fetch it or assume a symbol.
// ─────────────────────────────────────────────

// Matches the backend's PAYMENTS_CURRENCY default; only reached by a client
// component rendered outside the root layout's provider.
const CurrencyContext = createContext<string>("INR");

interface CurrencyProviderProps {
  currency: string;
  children: React.ReactNode;
}

export function CurrencyProvider({ currency, children }: CurrencyProviderProps) {
  return <CurrencyContext.Provider value={currency}>{children}</CurrencyContext.Provider>;
}

/** The ISO-4217 code every *_cents amount from the API is denominated in. */
export function useCurrency(): string {
  return useContext(CurrencyContext);
}

/** Formats a minor-unit amount in the deployment's currency — `money(1999)`. */
export function useMoney(): (minorUnits: number) => string {
  const currency = useCurrency();
  return (minorUnits: number) => formatMoney(minorUnits, currency);
}
