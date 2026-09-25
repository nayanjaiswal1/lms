"use client";

import Link from "next/link";
import { useState, type ComponentProps } from "react";

type HoverPrefetchLinkProps = Omit<ComponentProps<typeof Link>, "prefetch">;

// Eager load on intent: the default viewport prefetch only fetches the route's
// loading shell; on hover/touch this flips to prefetch={true}, which fetches the
// full page data so it's usually in the router cache before the click lands.
// Scoped to nav links — viewport-full-prefetching all ~40 of them on every
// load would cost dozens of server renders per visit.
export function HoverPrefetchLink({ onMouseEnter, onTouchStart, ...props }: HoverPrefetchLinkProps) {
  const [intent, setIntent] = useState(false);
  return (
    <Link
      {...props}
      prefetch={intent ? true : null}
      onMouseEnter={(e) => {
        setIntent(true);
        onMouseEnter?.(e);
      }}
      onTouchStart={(e) => {
        setIntent(true);
        onTouchStart?.(e);
      }}
    />
  );
}
