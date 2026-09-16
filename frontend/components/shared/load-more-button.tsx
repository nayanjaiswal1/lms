"use client";

import { parseAsInteger, useQueryState } from "nuqs";
import { Button } from "@/components/ui/button";

interface LoadMoreButtonProps {
  /** Only rendered when the last fetch returned a full page — a hint more rows exist. */
  hasMore: boolean;
  defaultLimit: number;
  step: number;
  max: number;
}

/** Bumps the shared `?limit=` search param, which the server component this
 * renders under re-reads to fetch a bigger page — see journal/mistakes
 * pages. `shallow: false` forces the server round trip nuqs otherwise skips. */
export function LoadMoreButton({ hasMore, defaultLimit, step, max }: LoadMoreButtonProps) {
  const [limit, setLimit] = useQueryState(
    "limit",
    parseAsInteger.withDefault(defaultLimit).withOptions({ shallow: false }),
  );

  if (!hasMore || limit >= max) return null;

  return (
    <div className="flex justify-center pt-4">
      <Button variant="outline" onClick={() => void setLimit(Math.min(limit + step, max))}>
        Load more
      </Button>
    </div>
  );
}
