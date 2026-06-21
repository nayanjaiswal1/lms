"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { inviteMembersAction } from "@/lib/batches/actions";
import type { InvitationToken } from "@/lib/batches/actions";

interface State { error?: string }

interface BulkInviteFormProps {
  batchId: string;
  onSuccess?: (tokens: InvitationToken[]) => void;
}

export function BulkInviteForm({ batchId, onSuccess }: BulkInviteFormProps) {
  const [state, formAction, pending] = useActionState(
    async (_prev: State | null, fd: globalThis.FormData): Promise<State | null> => {
      const raw = (fd.get("emails") as string) ?? "";
      const emails = raw.split(/[\s,;]+/).map((e) => e.trim()).filter(Boolean);
      if (emails.length === 0) return { error: "Enter at least one email address." };
      if (emails.length > 500) return { error: "Maximum 500 emails per batch." };

      const invalidEmail = emails.find((e) => !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e));
      if (invalidEmail) return { error: `Invalid email: ${invalidEmail}` };

      const result = await inviteMembersAction(batchId, emails);
      if (!result.ok) return { error: result.error };
      onSuccess?.(result.data?.tokens ?? []);
      return null;
    },
    null,
  );

  return (
    <form action={formAction} className="form-stack">
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="invite-emails">Student emails</Label>
        <Textarea
          required
          aria-label="Student emails, one per line or comma-separated"
          className="resize-none font-mono text-sm"
          disabled={pending}
          id="invite-emails"
          name="emails"
          placeholder={"student1@example.com\nstudent2@example.com"}
          rows={6}
        />
      </div>
      {state?.error && <p className="text-sm text-destructive">{state.error}</p>}
      <Button disabled={pending} type="submit">
        {pending ? "Sending invitations…" : "Send invitations"}
      </Button>
    </form>
  );
}
