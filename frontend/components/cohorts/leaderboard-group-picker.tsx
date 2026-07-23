"use client";

import { useRouter, usePathname } from "next/navigation";

import { CohortGroupTree } from "@/components/cohorts/cohort-group-tree";
import type { CohortGroup, CohortGroupNode } from "@/lib/server/cohorts";

interface LeaderboardGroupPickerProps {
  roots: CohortGroupNode[];
  allGroups: CohortGroup[];
  selectedId?: string;
}

// Thin client wrapper around CohortGroupTree — CohortGroupTree itself has no
// "use client" directive, so the router.push callback lives here, keeping
// the client boundary as deep (leaf) as possible. Mirrors ScopeTabs'
// pathname + URLSearchParams push exactly, so both controls agree on the URL
// contract the leaderboard page reads from.
export function LeaderboardGroupPicker({ roots, allGroups, selectedId }: LeaderboardGroupPickerProps) {
  const router = useRouter();
  const pathname = usePathname();

  return (
    <CohortGroupTree
      allGroups={allGroups}
      mode="picker"
      roots={roots}
      selectedId={selectedId}
      onSelect={(id) => router.push(`${pathname}?${new URLSearchParams({ scope: "group", scope_id: id })}`)}
    />
  );
}
