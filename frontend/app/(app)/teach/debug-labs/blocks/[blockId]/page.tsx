import Link from "next/link";
import type { Metadata } from "next";
import { Pencil } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { BackLink } from "@/components/labs/builder/back-link";
import { TextBlockDeleteButton } from "@/components/labs/builder/text-block-delete-button";
import { YankVersionButton } from "@/components/labs/builder/yank-version-button";
import { Button } from "@/components/ui/button";
import { canManageBlocks, getBlock, isPlatformAdmin, requireLabAuthor } from "@/lib/labs/builder/server";
import { isTextKind } from "@/lib/labs/builder/text-blocks";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = { title: "Block" };

interface BlockPageProps {
  params: Promise<{ blockId: string }>;
}

/** One block: its versions (newest first), changelogs, usage and yank status. */
export default async function BlockPage({ params }: BlockPageProps) {
  await requireLabAuthor();
  const { blockId } = await params;
  const [block, canManage, canYank] = await Promise.all([getBlock(blockId), canManageBlocks(), isPlatformAdmin()]);
  const editable = canManage && block.org_owned && isTextKind(block.kind);
  const latest = block.versions[0]?.manifest;

  return (
    <main className="page-container-sm flex flex-col gap-6">
      <BackLink href={ROUTES.LAB_BUILDER_BLOCKS} label="Block library" />
      <div className="page-header">
        <div className="min-w-0">
          <div className="mb-2 flex flex-wrap gap-1.5">
            <Badge className="badge-info" variant="outline">{block.kind}</Badge>
            <Badge className="badge-muted" variant="outline">{block.stack}</Badge>
            {latest?.difficulty && <Badge className="badge-muted" variant="outline">{latest.difficulty}</Badge>}
          </div>
          <h1 className="page-title">{latest?.title ?? block.block_key}</h1>
          <p className="break-all font-mono text-xs text-muted-foreground">{block.block_key}</p>
        </div>
        {editable && (
          <div className="flex flex-wrap gap-2">
            <Button asChild variant="outline">
              <Link href={ROUTES.labBuilderBlockEdit(block.id)}>
                <Pencil aria-hidden className="mr-2 h-4 w-4" />
                Edit
              </Link>
            </Button>
            <TextBlockDeleteButton blockId={block.id} />
          </div>
        )}
      </div>
      {latest?.summary && <p className="text-sm">{latest.summary}</p>}
      {(latest?.requires?.length ?? 0) > 0 && (
        <p className="text-sm text-muted-foreground">Requires: {latest?.requires?.join(", ")}</p>
      )}
      {(latest?.provides?.length ?? 0) > 0 && (
        <p className="text-sm text-muted-foreground">Provides: {latest?.provides?.join(", ")}</p>
      )}

      <section aria-label="Versions" className="flex flex-col gap-3">
        <h2 className="text-lg font-semibold">Versions</h2>
        <ol className="flex flex-col gap-3">
          {block.versions.map((v) => (
            <li className="card-base flex flex-col gap-2" key={v.id}>
              <div className="flex flex-wrap items-center gap-2">
                <span className="font-mono text-sm font-semibold">{v.version}</span>
                {v.yanked_at && <Badge className="badge-destructive" variant="outline">Yanked</Badge>}
                <span className="text-xs text-muted-foreground">{new Date(v.created_at).toLocaleDateString()}</span>
                {canYank && !v.yanked_at && (
                  <span className="ml-auto">
                    <YankVersionButton blockId={block.id} version={v.version} versionId={v.id} />
                  </span>
                )}
              </div>
              {v.changelog && <p className="text-sm">{v.changelog}</p>}
              {v.yanked_reason && <p className="text-sm text-destructive">Yanked: {v.yanked_reason}</p>}
              <p className="text-xs text-muted-foreground">
                Used by {v.recipe_count} of your recipe{v.recipe_count === 1 ? "" : "s"} · {v.lab_count} published lab
                {v.lab_count === 1 ? "" : "s"}
              </p>
            </li>
          ))}
        </ol>
      </section>
    </main>
  );
}
