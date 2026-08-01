/** Session date/time formatting shared by the session list card and detail page. */
export function formatSessionRange(
  startsAt: string,
  endsAt: string,
  dateStyle: "medium" | "full" = "medium",
): string {
  const start = new Date(startsAt);
  const end = new Date(endsAt);
  const date = new Intl.DateTimeFormat(undefined, { dateStyle }).format(start);
  const startTime = new Intl.DateTimeFormat(undefined, { timeStyle: "short" }).format(start);
  const endTime = new Intl.DateTimeFormat(undefined, { timeStyle: "short" }).format(end);
  return `${date} · ${startTime}–${endTime}`;
}
