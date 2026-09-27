"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import { CommentsPanel } from "@/components/workspace/comments/comments-panel";
import { AIToolsPanel } from "@/components/workspace/items/ai-tools-panel";
import { ConflictDialog } from "@/components/workspace/items/conflict-dialog";
import { DocTab } from "@/components/workspace/items/doc-tab";
import { EventsTimeline } from "@/components/workspace/items/events-timeline";
import { GitlabTab } from "@/components/workspace/items/gitlab-tab";
import { ItemBanners } from "@/components/workspace/items/item-banners";
import { TimeLogPanel } from "@/components/workspace/items/time-log-panel";
import { useProjectRole } from "@/components/workspace/project-role-provider";
import { updateWorkItemAction } from "@/lib/workspace/items-actions";
import type { WorkspaceComment } from "@/lib/workspace/phase3-server";
import type { DocView, GitlabLink, ItemDetail, ItemEvent, Member, Page, TimeLog, Track, WorkItem } from "@/lib/workspace/types";

interface ItemOverviewTabsProps {
  workspaceId: string;
  item: ItemDetail;
  eventsPage: Page<ItemEvent>;
  commentsPage: Page<WorkspaceComment>;
  members: Member[];
  tracks: Track[];
  /** Only set for type === "feature" (page.tsx skips the fetch otherwise). */
  doc: DocView | null;
  gitlabEnabled: boolean;
  gitlabLinks: GitlabLink[];
  timeLogsPage: Page<TimeLog>;
}

export function ItemOverviewTabs({
  workspaceId,
  item,
  eventsPage,
  commentsPage,
  members,
  tracks,
  doc,
  gitlabEnabled,
  gitlabLinks,
  timeLogsPage,
}: ItemOverviewTabsProps) {
  const router = useRouter();
  const { atLeast, isLeadOf } = useProjectRole();
  const [editing, setEditing] = useState(false);
  const [description, setDescription] = useState(item.description ?? "");
  const [pending, startTransition] = useTransition();
  const [conflict, setConflict] = useState<WorkItem | null>(null);

  function save(version: number) {
    startTransition(async () => {
      const result = await updateWorkItemAction(workspaceId, item.id, { version, description });
      if (result.conflict) {
        setConflict(result.conflict);
        return;
      }
      if (result.error) {
        toast.error(result.error);
        return;
      }
      toast.success("Description updated.");
      setEditing(false);
      router.refresh();
    });
  }

  return (
    <Tabs defaultValue="overview">
      <TabsList>
        <TabsTrigger value="overview">Overview</TabsTrigger>
        {doc && <TabsTrigger value="doc">Doc</TabsTrigger>}
        <TabsTrigger value="discussion">Discussion</TabsTrigger>
        <TabsTrigger value="time">Time</TabsTrigger>
        {gitlabEnabled && <TabsTrigger value="gitlab">GitLab</TabsTrigger>}
        <TabsTrigger value="activity">Activity</TabsTrigger>
      </TabsList>

      <TabsContent className="flex flex-col gap-4" value="overview">
        <ItemBanners item={item} workspaceId={workspaceId} />

        <AIToolsPanel
          canManage={atLeast("manager") || (item.track_id !== null && isLeadOf(item.track_id))}
          item={item}
          tracks={tracks}
          workspaceId={workspaceId}
        />

        {editing ? (
          <div className="flex flex-col gap-2">
            <Textarea rows={8} value={description} onChange={(e) => setDescription(e.target.value)} />
            <div className="flex justify-end gap-2">
              <Button disabled={pending} size="sm" variant="outline" onClick={() => { setDescription(item.description ?? ""); setEditing(false); }}>
                Cancel
              </Button>
              <Button disabled={pending} size="sm" onClick={() => save(item.version)}>
                {pending ? "Saving…" : "Save"}
              </Button>
            </div>
          </div>
        ) : (
          <div className="flex flex-col gap-2">
            <p className="prose-content whitespace-pre-wrap text-sm">{item.description || "No description yet."}</p>
            {item.can_edit && (
              <Button className="w-fit" size="sm" variant="outline" onClick={() => setEditing(true)}>
                Edit description
              </Button>
            )}
          </div>
        )}

        <ConflictDialog
          canOverwrite={atLeast("manager")}
          current={conflict}
          fields={[{ label: "Description", yours: description, current: conflict?.description ?? "" }]}
          open={conflict !== null}
          pending={pending}
          onOpenChange={(o) => !o && setConflict(null)}
          onOverwrite={(version) => save(version)}
          onReload={() => { setConflict(null); router.refresh(); }}
        />
      </TabsContent>

      {doc && (
        <TabsContent value="doc">
          <DocTab doc={doc} item={item} members={members} workspaceId={workspaceId} />
        </TabsContent>
      )}

      <TabsContent value="discussion">
        <CommentsPanel initialPage={commentsPage} subjectId={item.id} subjectType="work_item" workspaceId={workspaceId} />
      </TabsContent>

      <TabsContent value="time">
        <TimeLogPanel initialPage={timeLogsPage} itemId={item.id} workspaceId={workspaceId} />
      </TabsContent>

      {gitlabEnabled && (
        <TabsContent value="gitlab">
          <GitlabTab links={gitlabLinks} />
        </TabsContent>
      )}

      <TabsContent value="activity">
        <EventsTimeline initialPage={eventsPage} itemId={item.id} workspaceId={workspaceId} />
      </TabsContent>
    </Tabs>
  );
}
