import type { Metadata } from "next";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Eye } from "lucide-react";

import { requireAccess } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import { getOrgRole } from "@/lib/server/auth";
import { getWikiSpace, getWikiPage, getWikiTemplates, resolvePageIdFromPath } from "@/lib/server/wiki";
import { WikiSidebarTree } from "@/components/wiki/wiki-sidebar-tree";
import { WikiEditor } from "@/components/wiki/wiki-editor";
import { WikiVersionHistory } from "@/components/wiki/wiki-version-history";
import { Button } from "@/components/ui/button";
import { Breadcrumb, type BreadcrumbItem } from "@/components/shared/breadcrumb";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ spaceSlug: string; path: string[] }>;
}

export const metadata: Metadata = { title: "Edit — Wiki" };

export default async function WikiPageEditPage({ params }: Props) {
  await requireAccess(FEATURES.WIKI);
  const { spaceSlug, path } = await params;

  const orgRole = await getOrgRole();
  const canManage = orgRole === "admin" || orgRole === "instructor" || orgRole === "mentor";
  if (!canManage) redirect(ROUTES.wikiPage(spaceSlug, ...path));

  const [space, templates] = await Promise.all([getWikiSpace(spaceSlug), getWikiTemplates()]);

  const pageId = resolvePageIdFromPath(space.tree, path);
  if (!pageId) notFound();
  const page = await getWikiPage(pageId);

  const breadcrumbItems: BreadcrumbItem[] = [
    { label: "Wiki", href: ROUTES.WIKI },
    { label: page.space_name, href: ROUTES.wikiSpace(spaceSlug) },
    ...page.breadcrumb.slice(0, -1).map((b, i) => ({
      label: b.title,
      href: ROUTES.wikiPage(spaceSlug, ...page.breadcrumb.slice(0, i + 1).map((a) => a.slug)),
    })),
    { label: "Edit" },
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
            <Button asChild size="sm" variant="outline">
              <Link href={ROUTES.wikiPage(spaceSlug, ...path)}>
                <Eye aria-hidden className="mr-2 h-4 w-4" />
                View
              </Link>
            </Button>
          </div>

          <WikiEditor editable initialContent={page.content} initialTitle={page.title} pageId={page.id} />
        </article>
      </div>
    </main>
  );
}
