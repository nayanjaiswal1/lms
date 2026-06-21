"use client";

import { useActionState } from "react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { createInviteAction, type MemberActionState } from "@/app/org/settings/members/actions";
import type { OrgRole } from "@/lib/orgs/types";

const INVITE_ROLE_OPTIONS: { value: OrgRole; label: string }[] = [
  { value: "admin",      label: "Admin" },
  { value: "instructor", label: "Instructor" },
  { value: "mentor",     label: "Mentor" },
  { value: "learner",    label: "Learner" },
];

interface InviteFormProps {
  orgId: string;
}

export function InviteForm({ orgId }: InviteFormProps) {
  const [state, action, isPending] = useActionState<MemberActionState, FormData>(
    createInviteAction,
    {},
  );

  return (
    <form action={action} className="space-y-4">
      <input type="hidden" name="org_id" value={orgId} />

      <div className="stack-md">
        <div className="flex-1 space-y-1.5">
          <Label htmlFor="invite-email">Email address</Label>
          <Input
            autoComplete="email"
            id="invite-email"
            name="email"
            placeholder="colleague@example.com"
            required
            type="email"
          />
        </div>

        <div className="space-y-1.5">
          <Label htmlFor="invite-role">Role</Label>
          <Select defaultValue="learner" name="role" required>
            <SelectTrigger id="invite-role" aria-label="Select a role">
              <SelectValue placeholder="Select role" />
            </SelectTrigger>
            <SelectContent>
              {INVITE_ROLE_OPTIONS.map((opt) => (
                <SelectItem key={opt.value} value={opt.value}>
                  {opt.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>

      {state.error && (
        <p className="text-sm text-destructive" role="alert">{state.error}</p>
      )}

      <Button disabled={isPending} type="submit">
        {isPending ? "Sending…" : "Send Invite"}
      </Button>
    </form>
  );
}
