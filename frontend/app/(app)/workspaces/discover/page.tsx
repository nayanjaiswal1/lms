import type { Metadata } from "next";
import { LayoutGrid } from "lucide-react";

import { NextPageLink } from "@/components/shared/next-page-link";
import { DiscoverList } from "@/components/workspace/discover-list";
import { listDiscoverWorkspaces } from "@/lib/workspace/discover-server";

export const metadata: Metadata = {
  title: "Discover projects",
  description: "Browse recruiting workspaces and register your interest.",
};

interface DiscoverWorkspacesPageProps {
  searchParams: Promise<{ cursor?: string }>;
}

export default async function DiscoverWorkspacesPage({ searchParams }: DiscoverWorkspacesPageProps) {
  const { cursor } = await searchParams;
  const { items, next_cursor: nextCursor } = await listDiscoverWorkspaces(cursor);

  return (
    <main className="page-container">
      <header className="page-header">
        <div className="flex flex-col gap-1">
          <h1 className="page-title">Discover projects</h1>
          <p className="text-muted-foreground">Workspaces currently recruiting teammates.</p>
        </div>
      </header>

      {items.length === 0 ? (
        <div className="empty-state mt-10">
          <LayoutGrid aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="mt-3 font-medium">Nothing open right now</p>
          <p className="text-sm text-muted-foreground">Check back once a new project is posted.</p>
        </div>
      ) : (
        <div className="mt-8">
          <DiscoverList workspaces={items} />
          <NextPageLink nextCursor={nextCursor} />
        </div>
      )}
    </main>
  );
}
