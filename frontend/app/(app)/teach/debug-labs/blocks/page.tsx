import Link from "next/link";
import type { Metadata } from "next";
import { createLoader, type SearchParams } from "nuqs/server";
import { Blocks, Plus } from "lucide-react";
import { BackLink } from "@/components/labs/builder/back-link";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { BlockLibraryFilters } from "@/components/labs/builder/block-library-filters";
import { BLOCKS_ALL, blockLibraryParsers } from "@/lib/labs/builder/library-params";
import { canManageBlocks, getBlocks, requireLabAuthor } from "@/lib/labs/builder/server";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = { title: "Block library" };

const loadFilters = createLoader(blockLibraryParsers);

interface BlockLibraryPageProps {
  searchParams: Promise<SearchParams>;
}

// Block library (docs/debug-labs.md B4). Code blocks ship from the repo
// (content/lab-blocks/, `coursegen blocks sync`); org text blocks (ticket,
// hints, rubric, preset) are written here by anyone with labauthor.manage_blocks.
export default async function BlockLibraryPage({ searchParams }: BlockLibraryPageProps) {
  await requireLabAuthor();
  const { kind, stack } = await loadFilters(searchParams);
  const canManage = await canManageBlocks();
  const blocks = await getBlocks({
    kind: kind === BLOCKS_ALL ? undefined : kind,
    stack: stack === BLOCKS_ALL ? undefined : stack,
  });

  return (
    <main className="page-container flex flex-col gap-4">
      <BackLink href={ROUTES.LAB_BUILDER} label="All debug labs" />
      <div className="page-header py-2">
        <h1 className="page-title">Block library</h1>
        <div className="flex flex-wrap items-center gap-2">
          <BlockLibraryFilters />
          {canManage && (
            <Button asChild>
              <Link href={ROUTES.labBuilderBlockNew()}>
                <Plus aria-hidden className="h-4 w-4" />
                New text block
              </Link>
            </Button>
          )}
        </div>
      </div>
      {blocks.length === 0 ? (
        <div className="empty-state">
          <Blocks aria-hidden className="empty-state-icon" />
          <p>No blocks match these filters.</p>
        </div>
      ) : (
        <ul className="card-base flex flex-col divide-y divide-border overflow-hidden p-0">
          {blocks.map((b) => (
            <li key={b.id}>
              <Link
                className="flex flex-col gap-1 px-4 py-2.5 transition-colors duration-fast hover:bg-muted sm:flex-row sm:items-center sm:gap-3"
                href={ROUTES.labBuilderBlock(b.id)}
              >
                <span className="flex shrink-0 gap-1.5 sm:w-44">
                  <Badge className="badge-info" variant="outline">{b.kind}</Badge>
                  <Badge className="badge-muted" variant="outline">{b.stack}</Badge>
                  {b.org_owned && <Badge className="badge-muted" variant="outline">Your org</Badge>}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-sm font-medium">{b.title}</span>
                  <span className="block truncate text-xs text-muted-foreground">{b.summary}</span>
                </span>
                <span className="truncate font-mono text-xs text-muted-foreground sm:max-w-56">
                  {b.block_key}@{b.latest_version}
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
