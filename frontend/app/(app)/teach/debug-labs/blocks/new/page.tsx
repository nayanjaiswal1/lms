import Link from "next/link";
import type { Metadata } from "next";
import { BackLink } from "@/components/labs/builder/back-link";
import { TextBlockForm } from "@/components/labs/builder/text-block-form";
import { TEXT_BLOCK_KINDS } from "@/lib/labs/builder/options";
import { requireBlockManager, requireLabAuthor } from "@/lib/labs/builder/server";
import { isTextKind } from "@/lib/labs/builder/text-blocks";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = { title: "New block" };

interface NewBlockPageProps {
  searchParams: Promise<{ kind?: string }>;
}

/** Create an org text block (docs/debug-labs.md B4): markdown and params only, never executed. */
export default async function NewBlockPage({ searchParams }: NewBlockPageProps) {
  await requireLabAuthor();
  await requireBlockManager();
  const { kind } = await searchParams;
  const chosen = isTextKind(kind) ? TEXT_BLOCK_KINDS.find((k) => k.kind === kind) : undefined;

  return (
    <main className="page-container-sm flex flex-col gap-6">
      <BackLink href={ROUTES.LAB_BUILDER_BLOCKS} label="Block library" />
      <div className="page-header">
        <div>
          <h1 className="page-title">{chosen ? `New ${chosen.label.toLowerCase()} block` : "New block"}</h1>
          <p className="text-sm text-muted-foreground">
            {chosen?.description ?? "Text blocks are written in the browser and shared with your organization."}
          </p>
        </div>
      </div>
      {chosen ? (
        <TextBlockForm kind={chosen.kind} />
      ) : (
        <ul className="card-grid">
          {TEXT_BLOCK_KINDS.map((k) => (
            <li key={k.kind}>
              <Link className="card-interactive flex h-full flex-col gap-1" href={ROUTES.labBuilderBlockNew(k.kind)}>
                <h2 className="text-base font-semibold">{k.label}</h2>
                <p className="text-sm text-muted-foreground">{k.description}</p>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
