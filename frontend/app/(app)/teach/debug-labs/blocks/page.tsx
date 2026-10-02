import Link from "next/link";
import type { Metadata } from "next";
import { createLoader, type SearchParams } from "nuqs/server";
import { Blocks } from "lucide-react";
import { BackLink } from "@/components/labs/builder/back-link";
import { Badge } from "@/components/ui/badge";
import { BlockLibraryFilters } from "@/components/labs/builder/block-library-filters";
import { BLOCKS_ALL, blockLibraryParsers } from "@/lib/labs/builder/library-params";
import { getBlocks, requireLabAuthor } from "@/lib/labs/builder/server";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = { title: "Block library" };

const loadFilters = createLoader(blockLibraryParsers);

interface BlockLibraryPageProps {
  searchParams: Promise<SearchParams>;
}

// Read-only block library (docs/debug-labs.md B4). Code blocks ship from the
// repo (content/lab-blocks/, `coursegen blocks sync`); org text blocks arrive in Phase 2.
export default async function BlockLibraryPage({ searchParams }: BlockLibraryPageProps) {
  await requireLabAuthor();
  const { kind, stack } = await loadFilters(searchParams);
  const blocks = await getBlocks({
    kind: kind === BLOCKS_ALL ? undefined : kind,
    stack: stack === BLOCKS_ALL ? undefined : stack,
  });

  return (
    <main className="page-container flex flex-col gap-6">
      <BackLink href={ROUTES.LAB_BUILDER} label="All debug labs" />
      <div className="page-header">
        <div>
          <h1 className="page-title">Block library</h1>
          <p className="text-sm text-muted-foreground">
            Every tested building block a debug lab can be composed from, with its version history and usage.
          </p>
        </div>
      </div>
      <BlockLibraryFilters />
      {blocks.length === 0 ? (
        <div className="empty-state">
          <Blocks aria-hidden className="empty-state-icon" />
          <p>No blocks match these filters.</p>
        </div>
      ) : (
        <ul className="card-grid">
          {blocks.map((b) => (
            <li key={b.id}>
              <Link className="card-interactive flex h-full flex-col gap-2" href={ROUTES.labBuilderBlock(b.id)}>
                <div className="flex flex-wrap gap-1.5">
                  <Badge className="badge-info" variant="outline">{b.kind}</Badge>
                  <Badge className="badge-muted" variant="outline">{b.stack}</Badge>
                  {b.org_owned && <Badge className="badge-muted" variant="outline">Your org</Badge>}
                </div>
                <h2 className="text-base font-semibold">{b.title}</h2>
                <p className="truncate font-mono text-xs text-muted-foreground">
                  {b.block_key}@{b.latest_version}
                </p>
                <p className="text-sm text-muted-foreground">{b.summary}</p>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
