import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { FileText } from "lucide-react";

import { requireAccess } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import { getOrgRole } from "@/lib/server/auth";
import { getWikiSpace, getWikiTemplates } from "@/lib/server/wiki";
import { WikiSidebarTree } from "@/components/wiki/wiki-sidebar-tree";
import { WikiSearch } from "@/components/wiki/wiki-search";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ spaceSlug: string }>;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { spaceSlug } = await params;
  return { title: spaceSlug };
}

export default async function WikiSpacePage({ params }: Props) {
  await requireAccess(FEATURES.WIKI);
  const { spaceSlug } = await params;

  const [space, templates, orgRole] = await Promise.all([
    getWikiSpace(spaceSlug),
    getWikiTemplates(),
    getOrgRole(),
  ]);
  const canManage = orgRole === "admin" || orgRole === "instructor" || orgRole === "mentor";

  const firstPage = firstNode(space.tree);
  if (firstPage) {
    redirect(ROUTES.wikiPage(spaceSlug, ...firstPage));
  }

  return (
    <main className="page-container py-6">
      <div className="page-header">
        <div>
          <h1 className="page-title">{space.name}</h1>
          {space.description && <p className="text-sm text-muted-foreground">{space.description}</p>}
        </div>
      </div>

      <div className="mb-6 max-w-md">
        <WikiSearch spaceSlug={spaceSlug} />
      </div>

      <div className="flex flex-col items-start gap-6 lg:flex-row">
        <WikiSidebarTree
          canManage={canManage}
          currentPath={[]}
          spaceId={space.id}
          spaceSlug={spaceSlug}
          templates={templates}
          tree={space.tree}
        />
        <div className="empty-state min-w-0 flex-1">
          <FileText aria-hidden className="empty-state-icon" />
          <p className="font-medium text-muted-foreground">No pages yet.</p>
          <p className="text-sm text-muted-foreground">Use &quot;+ New Page&quot; in the sidebar to write the first one.</p>
        </div>
      </div>
    </main>
  );
}

function firstNode(tree: { slug: string }[]): string[] | null {
  const first = tree[0];
  return first ? [first.slug] : null;
}
