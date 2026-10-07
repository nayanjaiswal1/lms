const dollars = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });

/** Amounts are integer cents. */
export function formatMoney(cents) {
  return dollars.format(cents / 100);
}

/** A timestamp as the viewer's local calendar day, e.g. "Mar 5, 2025". */
export function formatDate(timestamp) {
  return new Date(timestamp).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
}
