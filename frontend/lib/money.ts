// Money formatting. Every amount the API returns is in the currency's *minor
// unit* (cents for USD, paise for INR, yen for JPY) — the `_cents` suffix on
// the API fields is historical, not a claim that a hundredth always exists.
//
// Which is why nothing here divides by 100: JPY and KRW have no minor unit at
// all, and dividing ¥1000 by 100 would price a course at ¥10. Intl already
// knows each currency's exponent, so the divisor is derived from it.

/** Minor units per major unit for a currency — 100 for USD, 1 for JPY. */
function minorUnitFactor(fmt: Intl.NumberFormat): number {
  return 10 ** (fmt.resolvedOptions().maximumFractionDigits ?? 2);
}

/**
 * Formats a minor-unit amount in the given ISO-4217 currency, localized to the
 * viewer. `currency` comes from the server (see lib/server/payments.ts) — never
 * hardcode a symbol at a call site, since the deployment's currency is a
 * PAYMENTS_CURRENCY setting, not a constant.
 */
export function formatMoney(minorUnits: number, currency: string, locale?: string): string {
  const fmt = new Intl.NumberFormat(locale, { style: "currency", currency });
  return fmt.format(minorUnits / minorUnitFactor(fmt));
}

/**
 * Converts a major-unit amount an admin typed (₹499, not 49900) into the
 * minor-unit integer the API stores — the input-side inverse of formatMoney.
 * Never hand-roll `* 100`: JPY/KRW have no minor unit, so the exponent must
 * come from Intl the same way formatMoney derives it.
 */
export function toMinorUnits(majorUnits: number, currency: string, locale?: string): number {
  const fmt = new Intl.NumberFormat(locale, { style: "currency", currency });
  return Math.round(majorUnits * minorUnitFactor(fmt));
}

/** The inverse convenience — pre-fills an edit form with the major-unit value. */
export function toMajorUnits(minorUnits: number, currency: string, locale?: string): number {
  const fmt = new Intl.NumberFormat(locale, { style: "currency", currency });
  return minorUnits / minorUnitFactor(fmt);
}
