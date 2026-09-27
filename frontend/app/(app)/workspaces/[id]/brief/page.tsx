import type { Metadata } from "next";

import { BriefView } from "@/components/workspace/brief/brief-view";
import { getWorkspaceBrief } from "@/lib/workspace/phase3-server";
import { getWorkspace } from "@/lib/workspace/server";

export const metadata: Metadata = {
  title: "Brief",
};

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function WorkspaceBriefPage({ params }: PageProps) {
  const { id } = await params;
  const [workspace, brief] = await Promise.all([getWorkspace(id), getWorkspaceBrief(id)]);

  return <BriefView brief={brief} wikiSpaceSlug={workspace.wiki_space_slug} workspaceId={id} />;
}
