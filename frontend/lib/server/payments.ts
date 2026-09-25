import "server-only";

import { cache } from "react";
import { baseURL } from "@/lib/server/api";

// Identical for every visitor and only changes on a backend redeploy, so it
// lives in Next's shared Data Cache instead of costing a call per render.
const CURRENCY_REVALIDATE_SECONDS = 3600;

// The currency every *_cents amount the API returns is denominated in, owned
// by the backend's PAYMENTS_CURRENCY (see internal/payments/handler.go).
// Fetched rather than mirrored into a NEXT_PUBLIC_ build var so there is only
// one place it can be wrong.
interface PaymentsConfig {
  currency: string;
}

// ISO-4217 fallback matching the backend's own PAYMENTS_CURRENCY default, used
// only when the config call fails — a price rendered in the wrong currency is
// worse than a page that still renders, but a page that doesn't render at all
// because the catalog couldn't reach one endpoint is worse than both. Must
// stay in step with config.go's getEnvDefault("PAYMENTS_CURRENCY", …).
const FALLBACK_CURRENCY = "INR";

/**
 * Resolved once per render tree via React `cache()`. Safe in the shared path
 * (unlike getFeatureConfig, this payload is identical for every visitor and
 * carries nothing per-user), and readable anonymously so the public catalog
 * can price courses before any session exists.
 */
export const getPaymentsCurrency = cache(async (): Promise<string> => {
  try {
    const res = await fetch(`${baseURL()}/api/public/payments/config`, {
      next: { revalidate: CURRENCY_REVALIDATE_SECONDS },
    });
    if (!res.ok) return FALLBACK_CURRENCY;
    const cfg = (await res.json() as { data: PaymentsConfig }).data;
    return cfg.currency || FALLBACK_CURRENCY;
  } catch {
    return FALLBACK_CURRENCY;
  }
});
