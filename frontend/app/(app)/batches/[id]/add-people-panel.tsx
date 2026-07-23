"use client";

import * as React from "react";
import { ArrowLeft, History, Plus, Search, UserPlus } from "lucide-react";
import { useRouter } from "next/navigation";
import { parseAsBoolean, parseAsStringEnum, useQueryState } from "nuqs";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { addBatchMembersAction, importValidateAction, confirmImportAction } from "@/app/(app)/batches/actions";
import { addBatchMentorAction } from "@/lib/batches/actions";
import type { BatchInvitation, OrgMemberSummary } from "@/lib/server/batches";
import { InviteHistory } from "@/app/(app)/batches/[id]/invite-history";

type Role = "member" | "mentor";
type View = "people" | "history";
const VIEWS = ["people", "history"] as const;

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

// parseNewInviteQuery pulls a name + email out of one free-typed line, e.g.
// "Ravi Kumar ravi@example.com" or just "ravi@example.com" (name falls back
// to the email's local part). Returns null when the text has no email at all.
function parseNewInviteQuery(query: string): { fullName: string; email: string } | null {
  const tokens = query.trim().split(/[\s,]+/).filter(Boolean);
  const emailToken = tokens.find((t) => EMAIL_RE.test(t));
  if (!emailToken) return null;
  const nameTokens = tokens.filter((t) => t !== emailToken);
  const fullName = nameTokens.join(" ") || emailToken.split("@")[0];
  return { fullName, email: emailToken.toLowerCase() };
}

interface AddPeoplePanelProps {
  batchId: string;
  orgMembers: OrgMemberSummary[];
  currentMemberIds: string[];
  currentMentorIds: string[];
  invitations: BatchInvitation[];
}

// useAddPeopleForm owns search text, the checked rows, each row's picked
// role, and submit-in-flight — kept in one hook so the component stays
// within the 2-useState limit.
function useAddPeopleForm() {
  const [query, setQuery] = React.useState("");
  const [submitting, setSubmitting] = React.useState(false);
  const [roleByUser, setRoleByUser] = React.useState<Record<string, Role>>({});
  const [selected, setSelected] = React.useState<Set<string>>(new Set());

  function setRole(userId: string, role: Role) {
    setRoleByUser((prev) => ({ ...prev, [userId]: role }));
  }

  function toggleSelected(userId: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(userId)) next.delete(userId);
      else next.add(userId);
      return next;
    });
  }

  return { query, setQuery, submitting, setSubmitting, roleByUser, setRole, selected, toggleSelected, setSelected };
}

export function AddPeoplePanel({ batchId, orgMembers, currentMemberIds, currentMentorIds, invitations }: AddPeoplePanelProps) {
  const [open, setOpen] = useQueryState("add-people", parseAsBoolean.withDefault(false));
  const [, setBulkImportOpen] = useQueryState("bulk-import", parseAsBoolean.withDefault(false));
  const [view, setView] = useQueryState("view", parseAsStringEnum<View>([...VIEWS]).withDefault("people"));
  const { query, setQuery, submitting, setSubmitting, roleByUser, setRole, selected, toggleSelected, setSelected } =
    useAddPeopleForm();
  const router = useRouter();

  function openBulkImport() {
    void setOpen(false);
    void setBulkImportOpen(true);
  }

  const memberIdSet = new Set(currentMemberIds);
  const mentorIdSet = new Set(currentMentorIds);

  const q = query.trim().toLowerCase();
  const filtered = q
    ? orgMembers.filter((m) => m.name.toLowerCase().includes(q) || m.email.toLowerCase().includes(q))
    : orgMembers;

  const noMatches = q !== "" && filtered.length === 0;
  const parsedInvite = noMatches ? parseNewInviteQuery(query) : null;

  function roleOf(userId: string): Role {
    return roleByUser[userId] ?? "member";
  }

  function alreadyAdded(userId: string, role: Role) {
    return role === "mentor" ? mentorIdSet.has(userId) : memberIdSet.has(userId);
  }

  async function addSelected() {
    const memberIds = [...selected].filter((id) => roleOf(id) === "member" && !alreadyAdded(id, "member"));
    const mentorIds = [...selected].filter((id) => roleOf(id) === "mentor" && !alreadyAdded(id, "mentor"));
    if (memberIds.length === 0 && mentorIds.length === 0) return;

    setSubmitting(true);
    const results = await Promise.all([
      memberIds.length > 0 ? addBatchMembersAction(batchId, memberIds) : null,
      ...mentorIds.map((id) => addBatchMentorAction(batchId, id)),
    ]);
    setSubmitting(false);

    const failed = results.filter((r) => r?.error);
    if (failed.length > 0) {
      toast.error(failed[0]?.error ?? "Some people couldn't be added.");
      return;
    }

    const total = memberIds.length + mentorIds.length;
    toast.success(`${total} ${total === 1 ? "person" : "people"} added.`);
    setSelected(new Set());
    router.refresh();
  }

  async function inviteNew() {
    if (!parsedInvite) return;
    setSubmitting(true);
    const row = { full_name: parsedInvite.fullName, email: parsedInvite.email, status: "new" as const };

    const validated = await importValidateAction(batchId, [row]);
    if (validated.error) {
      setSubmitting(false);
      toast.error(validated.error);
      return;
    }
    const validatedRow = validated.data?.rows[0] ?? row;
    if (validatedRow.status === "invalid" || validatedRow.status === "duplicate_in_file") {
      setSubmitting(false);
      toast.error(
        validatedRow.errors?.[0] ??
          (validatedRow.status === "invalid" ? "That email looks invalid." : "That person is already invited."),
      );
      return;
    }

    const confirmed = await confirmImportAction(batchId, {
      rows: [validatedRow],
      course_ids: [],
      mentor_ids: [],
      locked_fields: ["full_name"],
    });
    setSubmitting(false);
    if (confirmed.error) {
      toast.error(confirmed.error);
      return;
    }
    toast.success(`${parsedInvite.fullName} invited as student.`);
    setQuery("");
    router.refresh();
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm">
          <UserPlus aria-hidden className="mr-1.5 h-4 w-4" />
          Add people
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive max-h-[90vh] overflow-y-auto sm:max-w-2xl">
        <DialogHeader className="flex-row items-center gap-2 pr-16 space-y-0">
          {view === "history" ? (
            <>
              <Button
                aria-label="Back to add people"
                className="touch-target -ml-2 shrink-0"
                size="icon"
                variant="ghost"
                onClick={() => void setView("people")}
              >
                <ArrowLeft aria-hidden className="h-4 w-4" />
              </Button>
              <DialogTitle>Invite history</DialogTitle>
            </>
          ) : (
            <>
              <DialogTitle className="flex-1">Add people</DialogTitle>
              {invitations.length > 0 && (
                <Button
                  aria-label="View invite history"
                  className="touch-target shrink-0"
                  size="icon"
                  variant="ghost"
                  onClick={() => void setView("history")}
                >
                  <History aria-hidden className="h-4 w-4" />
                </Button>
              )}
            </>
          )}
        </DialogHeader>

        {view === "history" ? (
          <InviteHistory batchId={batchId} invitations={invitations} />
        ) : (
        <div className="flex w-full flex-col gap-4 min-w-0">
          <div className="flex items-center gap-2">
            <div className="relative flex-1 min-w-0">
              <Search aria-hidden className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground pointer-events-none" />
              <Input
                aria-label="Search org members by name or email, or type 'Name email@example.com' to invite someone new"
                className="pl-9"
                placeholder="Search, or type “Name email@example.com” to invite someone new…"
                type="text"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && parsedInvite) {
                    e.preventDefault();
                    void inviteNew();
                  }
                }}
              />
            </div>
            <Button className="shrink-0" disabled={selected.size === 0 || submitting} onClick={() => void addSelected()}>
              <Plus aria-hidden className="mr-1.5 h-4 w-4" />
              Add{selected.size > 0 ? ` (${selected.size})` : ""}
            </Button>
          </div>

          {noMatches ? (
            <div className="rounded-md border border-dashed border-border p-3 flex items-center justify-between gap-3">
              <p className="text-sm text-muted-foreground">
                {parsedInvite ? (
                  <>
                    No org members match. Invite <span className="font-medium text-foreground">{parsedInvite.fullName}</span>{" "}
                    (<span className="font-medium text-foreground">{parsedInvite.email}</span>) as a student.
                  </>
                ) : (
                  <>No org members match &ldquo;{query}&rdquo;. Include an email to invite them instead.</>
                )}
              </p>
              <Button disabled={!parsedInvite || submitting} size="sm" onClick={() => void inviteNew()}>
                <Plus aria-hidden className="mr-1.5 h-4 w-4" />
                Invite
              </Button>
            </div>
          ) : (
            <ul
              aria-label="Org members"
              className="max-h-72 overflow-y-auto divide-y divide-border rounded-md border border-border"
            >
              {filtered.map((m) => {
                const role = roleOf(m.user_id);
                const disabled = alreadyAdded(m.user_id, role) || submitting;
                return (
                  <li className="flex items-center gap-3 px-3 py-2.5 text-sm" key={m.user_id}>
                    <Checkbox
                      aria-label={`Select ${m.name}`}
                      checked={selected.has(m.user_id)}
                      disabled={disabled}
                      onCheckedChange={() => toggleSelected(m.user_id)}
                    />
                    <span className="flex flex-1 flex-col gap-0.5 min-w-0">
                      <span className="font-medium truncate">{m.name}</span>
                      <span className="text-xs text-muted-foreground truncate">{m.email}</span>
                    </span>
                    {disabled && !submitting ? (
                      <span className="shrink-0 rounded bg-muted px-1.5 py-0.5 text-xs capitalize text-muted-foreground">
                        Already {role === "mentor" ? "mentor" : "student"}
                      </span>
                    ) : (
                      <Select value={role} onValueChange={(v) => setRole(m.user_id, v as Role)}>
                        <SelectTrigger aria-label={`Role for ${m.name}`} className="h-8 w-[104px] shrink-0">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="member">Student</SelectItem>
                          <SelectItem value="mentor">Mentor</SelectItem>
                        </SelectContent>
                      </Select>
                    )}
                  </li>
                );
              })}
            </ul>
          )}

          <p className="text-center text-xs text-muted-foreground">
            Adding many at once?{" "}
            <Button className="h-auto p-0 text-xs" variant="link" onClick={openBulkImport}>
              Bulk import from Excel
            </Button>
          </p>
        </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
