import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { Breadcrumb } from "@/components/shared/breadcrumb";
import { AssigneePicker } from "@/components/workspace/items/assignee-picker";
import { ItemChildren } from "@/components/workspace/items/item-children";
import { ItemHeader } from "@/components/workspace/items/item-header";
import { ItemOverviewTabs } from "@/components/workspace/items/item-overview-tabs";
import { LinksPanel } from "@/components/workspace/items/links-panel";
import { TransitionButtons } from "@/components/workspace/items/transition-buttons";
import { getCurrentUser } from "@/lib/server/auth";
import { getItemAncestors, getWorkItem, listItemEvents } from "@/lib/workspace/items-server";
import { getItemDoc, listItemComments } from "@/lib/workspace/phase3-server";
import { getItemGitlabLinks, listTimeLogs } from "@/lib/workspace/phase4-server";
import { getWorkspace, listWorkspaceMembers, listWorkspaceTracks } from "@/lib/workspace/server";
import ROUTES from "@/lib/routes";

interface PageProps {
  params: Promise<{ id: string; key: string }>;
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { id, key } = await params;
  try {
    const item = await getWorkItem(id, key);
    return { title: `${item.key} — ${item.title}` };
  } catch {
    return { title: "Item" };
  }
}

export default async function WorkItemPage({ params }: PageProps) {
  const { id, key } = await params;

  let item: Awaited<ReturnType<typeof getWorkItem>>;
  try {
    item = await getWorkItem(id, key);
  } catch {
    notFound();
  }

  const [ancestors, eventsPage, members, tracks, currentUser, commentsPage, doc, workspace, gitlabLinks, timeLogsPage] = await Promise.all([
    getItemAncestors(id, item),
    listItemEvents(id, item.id, undefined, 20),
    listWorkspaceMembers(id),
    listWorkspaceTracks(id),
    getCurrentUser(),
    listItemComments(id, item.id, undefined, 20),
    item.type === "feature" ? getItemDoc(id, item.id) : Promise.resolve(null),
    getWorkspace(id),
    getItemGitlabLinks(id, item.id),
    listTimeLogs(id, { item: item.id, limit: 50 }),
  ]);

  return (
    <div className="flex flex-col gap-6">
      <Breadcrumb
        items={[
          ...(ancestors.epic ? [{ label: ancestors.epic.title, href: ROUTES.workspaceItem(id, ancestors.epic.key) }] : []),
          ...(ancestors.feature ? [{ label: ancestors.feature.title, href: ROUTES.workspaceItem(id, ancestors.feature.key) }] : []),
          { label: item.key },
        ]}
      />

      <div className="flex flex-col gap-6 lg:flex-row">
        <div className="flex min-w-0 flex-1 flex-col gap-6">
          <ItemHeader item={item} workspaceId={id} />
          <ItemOverviewTabs
            commentsPage={commentsPage}
            doc={doc}
            eventsPage={eventsPage}
            gitlabEnabled={workspace.gitlab_enabled}
            gitlabLinks={gitlabLinks}
            item={item}
            members={members}
            timeLogsPage={timeLogsPage}
            tracks={tracks}
            workspaceId={id}
          />
        </div>

        <div className="flex w-full flex-col gap-6 lg:w-72 lg:shrink-0">
          <AssigneePicker
            currentUserId={currentUser?.id ?? ""}
            item={item}
            members={members.map((m) => ({ user_id: m.user_id, name: m.name }))}
            workspaceId={id}
          />
          <TransitionButtons item={item} workspaceId={id} />
          <LinksPanel item={item} workspaceId={id} />
          <ItemChildren item={item} tracks={tracks} workspaceId={id} />
        </div>
      </div>
    </div>
  );
}
