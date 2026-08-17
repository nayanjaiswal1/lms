"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import type { OrgRole } from "@/lib/orgs/types";
import { bulkCreateInvitesAction } from "@/app/(app)/users/actions";

const INVITE_ROLE_OPTIONS: { value: OrgRole; label: string }[] = [
  { value: "admin",      label: "Admin" },
  { value: "instructor", label: "Instructor" },
  { value: "mentor",     label: "Mentor" },
  { value: "learner",    label: "Learner" },
];

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const SKIPPED_REASON_LABEL: Record<string, string> = {
  invalid_email: "invalid email",
  duplicate: "duplicate in list",
  already_member: "already a member",
};

function parseEmails(raw: string): string[] {
  const tokens = raw.split(/[\s,;]+/).map((t) => t.trim().toLowerCase()).filter(Boolean);
  return [...new Set(tokens)];
}

interface Props {
  orgId: string;
}

// Invites are queued and emailed async (see bulkCreateInvitesAction) — the
// backend doesn't expose per-invite progress for this endpoint, so success
// just reports how many were queued vs. skipped, not a live send status.
export function BulkInviteForm({ orgId }: Props) {
  const [text, setText] = React.useState("");
  const [role, setRole] = React.useState<OrgRole>("learner");
  const [submitting, setSubmitting] = React.useState(false);
  const [skipped, setSkipped] = React.useState<{ email: string; reason: string }[] | null>(null);
  const router = useRouter();

  const emails = parseEmails(text);
  const invalidCount = emails.filter((e) => !EMAIL_RE.test(e)).length;

  async function handleSubmit() {
    if (emails.length === 0) return;
    setSubmitting(true);
    setSkipped(null);
    const result = await bulkCreateInvitesAction(orgId, emails, role);
    setSubmitting(false);

    if (result.error) {
      toast.error(result.error);
      return;
    }

    const { queued, skipped: skippedResult } = result.data ?? { queued: 0, skipped: [] };
    if (queued > 0) {
      toast.success(`${queued} ${queued === 1 ? "invite" : "invites"} queued.`);
      setText("");
      router.refresh();
    }
    setSkipped(skippedResult.length > 0 ? skippedResult : null);
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="space-y-1.5">
        <Label htmlFor="bulk-emails">Email addresses</Label>
        <Textarea
          className="min-h-32 font-mono text-sm"
          id="bulk-emails"
          placeholder={"one@example.com\ntwo@example.com, three@example.com"}
          value={text}
          onChange={(e) => setText(e.target.value)}
        />
        <p className="text-xs text-muted-foreground">
          One per line, or separated by commas/spaces.
          {emails.length > 0 && ` ${emails.length} address${emails.length === 1 ? "" : "es"} found.`}
          {invalidCount > 0 && ` ${invalidCount} look invalid and will be skipped.`}
        </p>
      </div>

      <div className="space-y-1.5">
        <Label htmlFor="bulk-role">Role</Label>
        <Select value={role} onValueChange={(v) => setRole(v as OrgRole)}>
          <SelectTrigger id="bulk-role" aria-label="Select a role">
            <SelectValue />
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

      {skipped && (
        <div className="rounded-md border border-dashed border-border p-3">
          <p className="text-xs font-medium text-muted-foreground mb-1.5">
            {skipped.length} skipped
          </p>
          <ul className="space-y-0.5 text-xs text-muted-foreground max-h-24 overflow-y-auto">
            {skipped.map((s) => (
              <li key={s.email}>
                {s.email} — {SKIPPED_REASON_LABEL[s.reason] ?? s.reason}
              </li>
            ))}
          </ul>
        </div>
      )}

      <Button disabled={emails.length === 0 || submitting} onClick={() => void handleSubmit()}>
        {submitting ? "Queuing…" : `Invite${emails.length > 0 ? ` (${emails.length})` : ""}`}
      </Button>
    </div>
  );
}
