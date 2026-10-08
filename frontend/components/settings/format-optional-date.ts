/** Locale date for an optional API timestamp; "Never" when the field is unset. */
export function formatOptionalDate(iso: string | null | undefined): string {
  if (!iso) return "Never";
  return new Date(iso).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
}
