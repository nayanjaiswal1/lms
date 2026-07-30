import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Pencil } from "lucide-react";

import { requireAccess } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import { getOrgRole, getCurrentUser } from "@/lib/server/auth";
import { getWikiSpace, getWikiPage, getWikiComments, getWikiTemplates, resolvePageIdFromPath } from "@/lib/server/wiki";
import { WikiSidebarTree } from "@/components/wiki/wiki-sidebar-tree";
import { WikiEditor } from "@/components/wiki/wiki-editor";
import { WikiVersionHistory } from "@/components/wiki/wiki-version-history";
import { WikiCommentsPanel } from "@/components/wiki/wiki-comments-panel";
import { Button } from "@/components/ui/button";
import { Breadcrumb, type BreadcrumbItem } from "@/components/shared/breadcrumb";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ spaceSlug: string; path: string[] }>;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { path } = await params;
  return { title: path[path.length - 1]?.replace(/-[a-f0-9]{8}$/, "") ?? "Wiki" };
}

export default async function WikiPagePage({ params }: Props) {
  await requireAccess(FEATURES.WIKI);
  const { spaceSlug, path } = await params;

  const [space, templates, orgRole, currentUser] = await Promise.all([
    getWikiSpace(spaceSlug),
    getWikiTemplates(),
    getOrgRole(),
    getCurrentUser(),
  ]);
  const canManage = orgRole === "admin" || orgRole === "instructor" || orgRole === "mentor";

  const pageId = resolvePageIdFromPath(space.tree, path);
  if (!pageId) notFound();

  const [page, comments] = await Promise.all([
    getWikiPage(pageId),
    getWikiComments(pageId),
  ]);

  const breadcrumbItems: BreadcrumbItem[] = [
    { label: "Wiki", href: ROUTES.WIKI },
    { label: page.space_name, href: ROUTES.wikiSpace(spaceSlug) },
    ...page.breadcrumb.slice(0, -1).map((b, i) => ({
      label: b.title,
      href: ROUTES.wikiPage(spaceSlug, ...page.breadcrumb.slice(0, i + 1).map((a) => a.slug)),
    })),
  ];

  return (
    <main className="page-container">
      <Breadcrumb items={breadcrumbItems} />

      <div className="flex flex-col items-start gap-6 lg:flex-row">
        <WikiSidebarTree
          canManage={canManage}
          currentPath={path}
          spaceId={space.id}
          spaceSlug={spaceSlug}
          templates={templates}
          tree={space.tree}
        />

        <article className="min-w-0 flex-1">
          <div className="mb-4 flex flex-wrap items-center justify-end gap-2">
            <WikiVersionHistory canRestore={canManage} pageId={page.id} />
            {canManage && (
              <Button asChild size="sm">
                <Link href={ROUTES.wikiEdit(spaceSlug, ...path)}>
                  <Pencil aria-hidden className="mr-2 h-4 w-4" />
                  Edit
                </Link>
              </Button>
            )}
          </div>

          <WikiEditor editable={false} initialContent={page.content} initialTitle={page.title} pageId={page.id} />

          <WikiCommentsPanel
            canModerate={orgRole === "admin"}
            currentUserId={currentUser?.id ?? ""}
            initialThreads={comments}
            pageId={page.id}
          />
        </article>
      </div>
    </main>
  );
}
