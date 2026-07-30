import type { Metadata } from "next";
import Link from "next/link";
import { BookOpen } from "lucide-react";

import { requireAccess } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import { getWikiSpaces } from "@/lib/server/wiki";
import { WikiSearch } from "@/components/wiki/wiki-search";
import { WikiNewSpaceTrigger } from "@/components/wiki/wiki-new-space-trigger";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = { title: "Wiki" };

export default async function WikiIndexPage() {
  await requireAccess(FEATURES.WIKI);
  const spaces = await getWikiSpaces();

  return (
    <main className="page-container">
      <div className="page-header">
        <div>
          <h1 className="page-title">Wiki</h1>
          <p className="text-sm text-muted-foreground">Spaces of nested pages your org writes and shares together.</p>
        </div>
        <WikiNewSpaceTrigger />
      </div>

      <div className="mb-6 max-w-md">
        <WikiSearch />
      </div>

      {spaces.length === 0 ? (
        <div className="empty-state">
          <BookOpen aria-hidden className="empty-state-icon" />
          <p className="font-medium text-muted-foreground">No spaces yet.</p>
          <p className="text-sm text-muted-foreground">Create a space to start writing pages.</p>
        </div>
      ) : (
        <div className="card-grid">
          {spaces.map((space) => (
            <Link className="card-base card-interactive p-6" href={ROUTES.wikiSpace(space.slug)} key={space.id}>
              <div className="flex items-center gap-2">
                {space.icon ? <span aria-hidden className="text-lg">{space.icon}</span> : <BookOpen aria-hidden className="h-5 w-5 text-muted-foreground" />}
                <h2 className="font-semibold text-foreground">{space.name}</h2>
              </div>
              {space.description && <p className="mt-2 line-clamp-2 text-sm text-muted-foreground">{space.description}</p>}
              {space.course_id && <span className="badge-success mt-3 inline-block rounded-full border px-2 py-0.5 text-xs">Course Docs</span>}
            </Link>
          ))}
        </div>
      )}
    </main>
  );
}
