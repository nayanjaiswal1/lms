/** Catalog titles carry a "Lab:" prefix that is noise on a page already about a lab. */
export function displayLabTitle(title: string): string {
  return title.replace(/^lab:\s*/i, "")
}
