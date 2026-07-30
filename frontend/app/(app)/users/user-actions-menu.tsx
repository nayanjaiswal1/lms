"use client";

import { useState, useTransition } from "react";
import { useQueryState } from "nuqs";
import { MoreVertical } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { useHasPermission } from "@/lib/auth/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import {
  removeUserAction,
  resetUserPasswordAction,
  updateUserStatusAction,
} from "@/app/(app)/users/actions";

interface Props {
  userId: string;
  memberId: string;
  name: string;
  email: string;
  status: string;
  orgId: string;
}

type ConfirmAction = "reset" | "toggle" | "remove";

export function UserActionsMenu({ userId, memberId, name, email, status, orgId }: Props) {
  const [, setManageRolesId] = useQueryState("manageRoles");
  const canManageMembers = useHasPermission(PERMISSIONS.ADMIN.MANAGE_MEMBERS);
  const [isPending, startTransition] = useTransition();
  const [confirmAction, setConfirmAction] = useState<ConfirmAction | null>(null);
  const willSuspend = status !== "suspended";

  function handleResetPassword() {
    startTransition(async () => {
      const result = await resetUserPasswordAction(email);
      if (result.error) toast.error(result.error);
      else toast.success("Password reset email sent.");
    });
  }

  function handleToggleStatus() {
    const next = willSuspend ? "suspended" : "active";
    startTransition(async () => {
      const result = await updateUserStatusAction(orgId, memberId, next);
      if (result.error) toast.error(result.error);
      else toast.success(next === "suspended" ? `${name} suspended.` : `${name} activated.`);
    });
  }

  function handleRemove() {
    startTransition(async () => {
      const result = await removeUserAction(orgId, memberId);
      if (result.error) toast.error(result.error);
      else toast.success(`${name} removed from organization.`);
    });
  }

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button aria-label={`Actions for ${name}`} className="touch-target" size="sm" variant="ghost">
            <MoreVertical aria-hidden className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onSelect={() => void setManageRolesId(userId)}>
            Manage roles
          </DropdownMenuItem>
          <DropdownMenuItem disabled={isPending} onSelect={() => setConfirmAction("reset")}>
            Reset password
          </DropdownMenuItem>
          {canManageMembers && (
            <>
              <DropdownMenuItem disabled={isPending} onSelect={() => setConfirmAction("toggle")}>
                {status === "suspended" ? "Activate" : "Suspend"}
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem
                className="text-destructive focus:text-destructive"
                disabled={isPending}
                onSelect={() => setConfirmAction("remove")}
              >
                Remove from organization
              </DropdownMenuItem>
            </>
          )}
        </DropdownMenuContent>
      </DropdownMenu>

      <ConfirmDialog
        confirmLabel="Send reset email"
        description={`This sends a password reset email to ${email}.`}
        open={confirmAction === "reset"}
        pending={isPending}
        title="Reset password?"
        onConfirm={handleResetPassword}
        onOpenChange={(open) => !open && setConfirmAction(null)}
      />
      <ConfirmDialog
        confirmLabel={willSuspend ? "Suspend" : "Activate"}
        description={
          willSuspend
            ? `${name} will lose access to the organization until reactivated.`
            : `${name} will regain access to the organization.`
        }
        destructive={willSuspend}
        open={confirmAction === "toggle"}
        pending={isPending}
        title={willSuspend ? `Suspend ${name}?` : `Activate ${name}?`}
        onConfirm={handleToggleStatus}
        onOpenChange={(open) => !open && setConfirmAction(null)}
      />
      <ConfirmDialog
        destructive
        confirmLabel="Remove"
        description={`${name} will lose all access to this organization's courses, batches, and content. This can't be undone.`}
        open={confirmAction === "remove"}
        pending={isPending}
        title={`Remove ${name} from organization?`}
        onConfirm={handleRemove}
        onOpenChange={(open) => !open && setConfirmAction(null)}
      />
    </>
  );
}
