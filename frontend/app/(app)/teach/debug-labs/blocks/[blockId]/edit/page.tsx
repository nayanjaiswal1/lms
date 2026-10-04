import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { BackLink } from "@/components/labs/builder/back-link";
import { TextBlockForm } from "@/components/labs/builder/text-block-form";
import { getBlock, requireBlockManager, requireLabAuthor } from "@/lib/labs/builder/server";
import { isTextKind } from "@/lib/labs/builder/text-blocks";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = { title: "Edit block" };

interface EditBlockPageProps {
  params: Promise<{ blockId: string }>;
}

/** Saving appends a new immutable version; recipes keep their pinned one until the author takes the update. */
export default async function EditBlockPage({ params }: EditBlockPageProps) {
  await requireLabAuthor();
  await requireBlockManager();
  const { blockId } = await params;
  const block = await getBlock(blockId);
  const latest = block.versions[0];
  if (!block.org_owned || !latest || !isTextKind(block.kind)) notFound();

  return (
    <main className="page-container-sm flex flex-col gap-6">
      <BackLink href={ROUTES.labBuilderBlock(blockId)} label="Back to block" />
      <div className="page-header">
        <div className="min-w-0">
          <h1 className="page-title">Edit {latest.manifest.title}</h1>
          <p className="text-sm text-muted-foreground">
            Based on version {latest.version}. Saving creates the next version; recipes pinned to older ones are unaffected.
          </p>
        </div>
      </div>
      <TextBlockForm existing={{ blockId, manifest: latest.manifest }} kind={block.kind} />
    </main>
  );
}
