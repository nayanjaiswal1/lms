"use client";

import * as React from "react";
import Link from "next/link";
import { toast } from "sonner";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { AddMemberDialog } from "@/components/workspace/add-member-dialog";
import { removeMemberAction, updateMemberRoleAction } from "@/lib/workspace/actions";
import { MEMBER_STATUS_LABEL, MEMBER_STATUS_VARIANT, PROJECT_ROLE_LABEL } from "@/lib/workspace/roles";
import type { Member, ProjectRole } from "@/lib/workspace/types";
import ROUTES from "@/lib/routes";

interface MemberListProps {
  workspaceId: string;
  members: Member[];
  currentUserId: string;
  isOwner: boolean;
  canManage: boolean;
  /** Structure edits are locked once the project leaves draft/recruiting/active (StatusesPlanning). */
  canEditStructure: boolean;
}

const ASSIGNABLE_ROLES: ProjectRole[] = ["viewer", "member", "manager"];

export function MemberList({ workspaceId, members, currentUserId, isOwner, canManage, canEditStructure }: MemberListProps) {
  const [pendingUserId, setPendingUserId] = React.useState<string | null>(null);
  const [removeTarget, setRemoveTarget] = React.useState<Member | null>(null);

  async function handleRoleChange(member: Member, role: ProjectRole) {
    setPendingUserId(member.user_id);
    const result = await updateMemberRoleAction(workspaceId, member.user_id, role);
    setPendingUserId(null);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`${member.name} is now ${PROJECT_ROLE_LABEL[role]}.`);
  }

  async function handleRemove(member: Member) {
    setPendingUserId(member.user_id);
    const result = await removeMemberAction(workspaceId, member.user_id);
    setPendingUserId(null);
    setRemoveTarget(null);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(member.user_id === currentUserId ? "You left the workspace." : `${member.name} removed.`);
  }

  function canRemove(member: Member): boolean {
    if (member.role === "owner" || (member.status !== "active" && member.status !== "invited")) return false;
    if (member.user_id === currentUserId) return true; // self-leave
    if (member.role === "manager") return isOwner;
    return canManage;
  }

  function canChangeRole(member: Member): boolean {
    return canManage && member.role !== "owner" && member.status === "active";
  }

  return (
    <div className="flex flex-col gap-4">
      {canManage && canEditStructure && (
        <div className="flex justify-end">
          <AddMemberDialog canGrantManager={isOwner} workspaceId={workspaceId} />
        </div>
      )}

      {members.length === 0 ? (
        <div className="empty-state">
          <p className="font-medium text-muted-foreground">No members yet.</p>
        </div>
      ) : (
        <ResponsiveTable>
          <table className="w-full text-sm">
            <thead>
              <tr className="whitespace-nowrap text-left text-xs text-muted-foreground">
                <th className="px-3 py-2">Name</th>
                <th className="px-3 py-2">Role</th>
                <th className="px-3 py-2">Status</th>
                <th className="px-3 py-2">Onboarding</th>
                <th className="px-3 py-2" />
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {members.map((member) => (
                <tr className="whitespace-nowrap" key={member.user_id}>
                  <td className="min-w-0 px-3 py-2">
                    <p className="truncate font-medium">{member.name}</p>
                    {member.email && <p className="truncate text-xs text-muted-foreground">{member.email}</p>}
                  </td>
                  <td className="px-3 py-2">
                    {canChangeRole(member) ? (
                      <Select
                        disabled={pendingUserId === member.user_id}
                        value={member.role}
                        onValueChange={(value) => handleRoleChange(member, value as ProjectRole)}
                      >
                        <SelectTrigger className="h-9 w-32">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          {ASSIGNABLE_ROLES.filter((r) => r !== "manager" || isOwner).map((r) => (
                            <SelectItem key={r} value={r}>{PROJECT_ROLE_LABEL[r]}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    ) : (
                      <Badge variant="outline">{PROJECT_ROLE_LABEL[member.role]}</Badge>
                    )}
                  </td>
                  <td className="px-3 py-2">
                    <Badge variant={MEMBER_STATUS_VARIANT[member.status]}>{MEMBER_STATUS_LABEL[member.status]}</Badge>
                  </td>
                  <td className="px-3 py-2">{member.onboarding_pct}%</td>
                  <td className="px-3 py-2 text-right">
                    {member.status === "active" && (
                      <Button asChild className="mr-2" size="sm" variant="ghost">
                        <Link href={ROUTES.workspaceMemberReport(workspaceId, member.user_id)}>Report</Link>
                      </Button>
                    )}
                    {canRemove(member) && (
                      <Button
                        disabled={pendingUserId === member.user_id}
                        size="sm"
                        variant="outline"
                        onClick={() => setRemoveTarget(member)}
                      >
                        {member.user_id === currentUserId ? "Leave" : "Remove"}
                      </Button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </ResponsiveTable>
      )}

      <ConfirmDialog
        destructive
        confirmLabel={removeTarget?.user_id === currentUserId ? "Leave" : "Remove"}
        description={
          removeTarget
            ? removeTarget.user_id === currentUserId
              ? "You'll lose access to this workspace immediately. Any open item you own will be unassigned, and any track you lead will need a new lead before it can take new assignments."
              : `${removeTarget.name} will lose access to this workspace immediately. Any open item they own will be unassigned, and any track they lead will need a new lead before it can take new assignments.`
            : ""
        }
        open={removeTarget !== null}
        pending={removeTarget !== null && pendingUserId === removeTarget.user_id}
        title={removeTarget ? (removeTarget.user_id === currentUserId ? "Leave this workspace?" : `Remove ${removeTarget.name}?`) : ""}
        onConfirm={() => removeTarget && handleRemove(removeTarget)}
        onOpenChange={(open) => !open && setRemoveTarget(null)}
      />
    </div>
  );
}
