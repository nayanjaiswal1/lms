const DAY_FORMAT = { year: 'numeric', month: 'short', day: 'numeric' };

export function formatMoney(cents, currency = 'USD', locale = 'en-US') {
  return new Intl.NumberFormat(locale, { style: 'currency', currency }).format(cents / 100);
}

// mf:slot format.date.parse
export function parseDay(day) {
  // A calendar day such as "2025-03-05" has no time zone, so build it in local time.
  const [year, month, date] = day.split('-').map(Number);
  return new Date(year, month - 1, date);
}
// mf:endslot

/** "2025-03-05" -> "Mar 5, 2025" */
export function formatDay(day, locale = 'en-US') {
  return parseDay(day).toLocaleDateString(locale, DAY_FORMAT);
}

/** An ISO timestamp (an instant) in the viewer's local time. */
export function formatDateTime(iso, locale = 'en-US') {
  return new Date(iso).toLocaleString(locale, { ...DAY_FORMAT, hour: '2-digit', minute: '2-digit' });
}
