"use client";

import * as React from "react";
import { toast } from "sonner";
import { UserCheck, UserMinus, X } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { CreateTrackDialog } from "@/components/workspace/create-track-dialog";
import {
  approveTrackMemberAction,
  deleteTrackAction,
  joinTrackAction,
  removeTrackMemberAction,
  updateTrackAction,
} from "@/lib/workspace/actions";
import type { Member, Track } from "@/lib/workspace/types";

interface TrackListProps {
  workspaceId: string;
  tracks: Track[];
  members: Member[];
  currentUserId: string;
  canManage: boolean;
  ledTrackIds: string[];
  /** Structure edits are locked once the project leaves draft/recruiting/active (StatusesPlanning). */
  canEditStructure: boolean;
}

export function TrackList({ workspaceId, tracks, members, currentUserId, canManage, ledTrackIds, canEditStructure }: TrackListProps) {
  const [pendingKey, setPendingKey] = React.useState<string | null>(null);
  const [deleteTarget, setDeleteTarget] = React.useState<Track | null>(null);
  const activeMembers = members.filter((m) => m.status === "active");

  function isLeadOf(trackId: string): boolean {
    return ledTrackIds.includes(trackId);
  }

  async function withPending(key: string, fn: () => Promise<{ error?: string }>) {
    setPendingKey(key);
    const result = await fn();
    setPendingKey(null);
    if (result.error) toast.error(result.error);
    return result;
  }

  async function handleSetLead(track: Track, leadUserId: string) {
    const result = await withPending(`lead-${track.id}`, () =>
      updateTrackAction(workspaceId, track.id, { lead_user_id: leadUserId === "none" ? null : leadUserId }),
    );
    if (!result.error) toast.success("Lead updated.");
  }

  async function handleDelete(track: Track) {
    const result = await withPending(`delete-${track.id}`, () => deleteTrackAction(workspaceId, track.id));
    setDeleteTarget(null);
    if (!result.error) toast.success("Track deleted.");
  }

  async function handleJoin(track: Track) {
    const result = await withPending(`join-${track.id}`, () => joinTrackAction(workspaceId, track.id, currentUserId));
    if (!result.error) toast.success(canManage || isLeadOf(track.id) ? "Joined." : "Requested — a lead or manager will approve.");
  }

  async function handleApprove(track: Track, userId: string) {
    const result = await withPending(`approve-${track.id}-${userId}`, () => approveTrackMemberAction(workspaceId, track.id, userId));
    if (!result.error) toast.success("Approved.");
  }

  async function handleRemoveMember(track: Track, userId: string, isSelf: boolean) {
    const result = await withPending(`remove-${track.id}-${userId}`, () => removeTrackMemberAction(workspaceId, track.id, userId));
    if (!result.error) toast.success(isSelf ? "Left the track." : "Removed from track.");
  }

  return (
    <div className="flex flex-col gap-4">
      {canManage && canEditStructure && (
        <div className="flex justify-end">
          <CreateTrackDialog workspaceId={workspaceId} />
        </div>
      )}

      {tracks.length === 0 ? (
        <div className="empty-state">
          <p className="font-medium text-muted-foreground">No tracks yet.</p>
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2">
          {tracks.map((track) => {
            const alreadyIn = track.members.some((m) => m.user_id === currentUserId);
            return (
              <div className="card-base flex flex-col gap-3" key={track.id}>
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <p className="truncate font-medium">{track.name}</p>
                    <p className="truncate text-xs text-muted-foreground">
                      Lead: {track.lead_name ?? "Unassigned"}
                    </p>
                  </div>
                  {canManage && canEditStructure && (
                    <Button
                      aria-label={`Delete ${track.name}`}
                      disabled={pendingKey === `delete-${track.id}`}
                      size="icon"
                      variant="ghost"
                      onClick={() => setDeleteTarget(track)}
                    >
                      <X aria-hidden className="h-4 w-4" />
                    </Button>
                  )}
                </div>

                {canManage && canEditStructure && (
                  <Select
                    disabled={pendingKey === `lead-${track.id}`}
                    value={track.lead_user_id ?? "none"}
                    onValueChange={(value) => handleSetLead(track, value)}
                  >
                    <SelectTrigger className="h-9">
                      <SelectValue placeholder="Set lead" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="none">Unassigned</SelectItem>
                      {activeMembers.map((m) => (
                        <SelectItem key={m.user_id} value={m.user_id}>{m.name}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}

                <ul className="flex flex-col gap-1.5">
                  {track.members.map((m) => (
                    <li className="flex items-center justify-between gap-2 text-sm" key={m.user_id}>
                      <span className="min-w-0 truncate">{m.name}</span>
                      <div className="flex items-center gap-1.5">
                        <Badge variant={m.status === "approved" ? "default" : "secondary"}>
                          {m.status === "approved" ? "Approved" : "Pending"}
                        </Badge>
                        {m.status === "pending" && (canManage || isLeadOf(track.id)) && (
                          <Button
                            aria-label={`Approve ${m.name}`}
                            disabled={pendingKey === `approve-${track.id}-${m.user_id}`}
                            size="icon"
                            variant="ghost"
                            onClick={() => handleApprove(track, m.user_id)}
                          >
                            <UserCheck aria-hidden className="h-4 w-4" />
                          </Button>
                        )}
                        {(m.user_id === currentUserId || canManage || isLeadOf(track.id)) && canEditStructure && (
                          <Button
                            aria-label={`Remove ${m.name} from track`}
                            disabled={pendingKey === `remove-${track.id}-${m.user_id}`}
                            size="icon"
                            variant="ghost"
                            onClick={() => handleRemoveMember(track, m.user_id, m.user_id === currentUserId)}
                          >
                            <UserMinus aria-hidden className="h-4 w-4" />
                          </Button>
                        )}
                      </div>
                    </li>
                  ))}
                </ul>

                {!alreadyIn && canEditStructure && (
                  <Button
                    disabled={pendingKey === `join-${track.id}`}
                    size="sm"
                    variant="outline"
                    onClick={() => handleJoin(track)}
                  >
                    Join this track
                  </Button>
                )}
              </div>
            );
          })}
        </div>
      )}

      <ConfirmDialog
        destructive
        confirmLabel="Delete"
        description={deleteTarget ? `"${deleteTarget.name}" and its membership will be removed.` : ""}
        open={deleteTarget !== null}
        pending={deleteTarget !== null && pendingKey === `delete-${deleteTarget.id}`}
        title={deleteTarget ? `Delete "${deleteTarget.name}"?` : "Delete track?"}
        onConfirm={() => deleteTarget && handleDelete(deleteTarget)}
        onOpenChange={(open) => !open && setDeleteTarget(null)}
      />
    </div>
  );
}
