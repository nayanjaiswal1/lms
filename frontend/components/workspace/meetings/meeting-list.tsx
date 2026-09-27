"use client";

import { useState } from "react";
import Link from "next/link";
import { toast } from "sonner";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { ActionItemDialog } from "@/components/workspace/meetings/action-item-dialog";
import { AttendanceDialog } from "@/components/workspace/meetings/attendance-dialog";
import { useProjectRole } from "@/components/workspace/project-role-provider";
import { apiFetch } from "@/lib/client/api";
import { MEETING_KIND_LABEL } from "@/lib/workspace/meetings-constants";
import type { Meeting, Member, Page } from "@/lib/workspace/types";
import ROUTES from "@/lib/routes";

interface MeetingListProps {
  workspaceId: string;
  initialPage: Page<Meeting>;
  members: Member[];
  wikiSpaceSlug: string | null;
}

export function MeetingList({ workspaceId, initialPage, members, wikiSpaceSlug }: MeetingListProps) {
  const { atLeast } = useProjectRole();
  const [meetings, setMeetings] = useState(initialPage.items);
  const [nextCursor, setNextCursor] = useState(initialPage.next_cursor);
  const [loadingMore, setLoadingMore] = useState(false);
  const [attendanceTarget, setAttendanceTarget] = useState<Meeting | null>(null);
  const [actionItemTarget, setActionItemTarget] = useState<Meeting | null>(null);

  async function loadMore() {
    if (!nextCursor) return;
    setLoadingMore(true);
    const page = await apiFetch<Page<Meeting>>(`/workspaces/${workspaceId}/meetings?cursor=${encodeURIComponent(nextCursor)}&limit=20`);
    setLoadingMore(false);
    if (!page) {
      toast.error("Could not load more meetings.");
      return;
    }
    setMeetings((prev) => [...prev, ...page.items]);
    setNextCursor(page.next_cursor);
  }

  if (meetings.length === 0) {
    return <div className="empty-state"><p className="text-sm text-muted-foreground">No meetings scheduled yet.</p></div>;
  }

  return (
    <div className="flex flex-col gap-4">
      <ResponsiveTable>
        <table className="w-full text-sm">
          <thead>
            <tr className="whitespace-nowrap border-b border-border text-left text-xs text-muted-foreground">
              <th className="px-3 py-2">Kind</th>
              <th className="px-3 py-2">Title</th>
              <th className="px-3 py-2">Starts</th>
              <th className="px-3 py-2">Notes</th>
              <th className="px-3 py-2" />
            </tr>
          </thead>
          <tbody>
            {meetings.map((m) => (
              <tr className="whitespace-nowrap border-b border-border last:border-0" key={m.calendar_event_id}>
                <td className="px-3 py-2"><Badge variant="outline">{MEETING_KIND_LABEL[m.kind]}</Badge></td>
                <td className="min-w-0 px-3 py-2 whitespace-normal">
                  {m.meeting_url ? (
                    <a className="truncate text-primary hover:underline" href={m.meeting_url} rel="noreferrer" target="_blank">{m.title}</a>
                  ) : (
                    <span className="truncate">{m.title}</span>
                  )}
                </td>
                <td className="px-3 py-2 text-muted-foreground">{new Date(m.starts_at).toLocaleString()}</td>
                <td className="px-3 py-2">
                  {m.notes_wiki_page_id && wikiSpaceSlug ? (
                    <Link className="text-primary hover:underline" href={ROUTES.wikiSpace(wikiSpaceSlug)}>Notes</Link>
                  ) : (
                    <span className="text-muted-foreground">—</span>
                  )}
                </td>
                <td className="px-3 py-2 text-right">
                  <div className="flex justify-end gap-1.5">
                    {atLeast("member") && (
                      <Button size="sm" variant="outline" onClick={() => setActionItemTarget(m)}>
                        Convert to ticket
                      </Button>
                    )}
                    {atLeast("manager") && (
                      <Button size="sm" variant="outline" onClick={() => setAttendanceTarget(m)}>
                        Attendance
                      </Button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </ResponsiveTable>

      {nextCursor && (
        <div className="flex justify-center">
          <Button disabled={loadingMore} variant="outline" onClick={loadMore}>
            {loadingMore ? "Loading…" : "Load more"}
          </Button>
        </div>
      )}

      {attendanceTarget && (
        <AttendanceDialog
          meeting={attendanceTarget}
          members={members}
          open={attendanceTarget !== null}
          workspaceId={workspaceId}
          onOpenChange={(o) => !o && setAttendanceTarget(null)}
        />
      )}
      {actionItemTarget && (
        <ActionItemDialog
          meeting={actionItemTarget}
          open={actionItemTarget !== null}
          workspaceId={workspaceId}
          onOpenChange={(o) => !o && setActionItemTarget(null)}
        />
      )}
    </div>
  );
}
