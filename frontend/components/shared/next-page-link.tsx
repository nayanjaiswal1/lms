import Link from "next/link";
import { Button } from "@/components/ui/button";

interface NextPageLinkProps {
  /** The page's next_cursor; nothing renders on the last page. */
  nextCursor?: string;
  /** The page's current search params, kept on the next page's URL. */
  searchParams?: Record<string, string | undefined>;
}

/** URL-driven "next page" for a cursor-paginated list (lib/pagination.ts): the
 *  server component re-reads ?cursor= and fetches the following page. */
export function NextPageLink({ nextCursor, searchParams = {} }: NextPageLinkProps) {
  if (!nextCursor) return null;
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(searchParams)) {
    if (value && key !== "cursor") params.set(key, value);
  }
  params.set("cursor", nextCursor);
  return (
    <div className="flex justify-center pt-4">
      <Button asChild variant="outline">
        <Link href={`?${params}`}>Older</Link>
      </Button>
    </div>
  );
}
