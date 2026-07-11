"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { Plus, Search, Trash2, UserPlus } from "lucide-react";
import { toast } from "sonner";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { addBatchMembersAction, importValidateAction, confirmImportAction } from "@/app/(app)/batches/actions";
import type { ImportMemberRow } from "@/lib/server/batches";

export interface OrgMember {
  user_id: string;
  name: string;
  email: string;
  role: string;
}

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

// useAddStudentsForm owns search, existing-member selection, and the queue of
// brand-new people to invite — kept in one hook so the component stays within
// the 2-useState limit.
function useAddStudentsForm(batchId: string, onDone: () => void) {
  const [query, setQuery] = React.useState("");
  const [selectedExisting, setSelectedExisting] = React.useState<Set<string>>(new Set());
  const [newInvites, setNewInvites] = React.useState<ImportMemberRow[]>([]);
  const [submitting, setSubmitting] = React.useState(false);
  const router = useRouter();

  function toggleExisting(userId: string) {
    setSelectedExisting((prev) => {
      const next = new Set(prev);
      if (next.has(userId)) next.delete(userId);
      else next.add(userId);
      return next;
    });
  }

  function queueNewInvite(query: string) {
    const parsed = parseNewInviteQuery(query);
    if (!parsed) return;
    setNewInvites((prev) => [...prev, { full_name: parsed.fullName, email: parsed.email, status: "new" }]);
    setQuery("");
  }

  function removeNewInvite(index: number) {
    setNewInvites((prev) => prev.filter((_, i) => i !== index));
  }

  function updateNewInvite(index: number, name: string) {
    setNewInvites((prev) => {
      const next = prev.slice();
      next[index] = { ...next[index], full_name: name };
      return next;
    });
  }

  function reset() {
    setQuery("");
    setSelectedExisting(new Set());
    setNewInvites([]);
  }

  async function submit() {
    if (selectedExisting.size === 0 && newInvites.length === 0) return;
    setSubmitting(true);

    if (selectedExisting.size > 0) {
      const result = await addBatchMembersAction(batchId, Array.from(selectedExisting));
      if (result.error) {
        setSubmitting(false);
        toast.error(result.error);
        return;
      }
    }

    if (newInvites.length > 0) {
      const validated = await importValidateAction(batchId, newInvites);
      if (validated.error) {
        setSubmitting(false);
        toast.error(validated.error);
        return;
      }
      const validatedRows = validated.data?.rows ?? newInvites;
      const blocking = validatedRows.filter((r) => r.status === "invalid" || r.status === "duplicate_in_file");
      if (blocking.length > 0) {
        setNewInvites(validatedRows);
        setSubmitting(false);
        toast.error("Fix the highlighted new invite(s) before sending.");
        return;
      }
      const confirmed = await confirmImportAction(batchId, {
        rows: validatedRows,
        course_ids: [],
        mentor_ids: [],
        locked_fields: ["full_name"],
      });
      if (confirmed.error) {
        setSubmitting(false);
        toast.error(confirmed.error);
        return;
      }
    }

    setSubmitting(false);
    const total = selectedExisting.size + newInvites.length;
    toast.success(`${total} student${total === 1 ? "" : "s"} added.`);
    reset();
    onDone();
    router.refresh();
  }

  return { query, setQuery, selectedExisting, toggleExisting, newInvites, queueNewInvite, removeNewInvite, updateNewInvite, submitting, submit, reset };
}

interface AddStudentsFormProps {
  batchId: string;
  orgMembers: OrgMember[];
  currentMemberIds: string[];
  onClose: () => void;
}

export function AddStudentsForm({ batchId, orgMembers, currentMemberIds, onClose }: AddStudentsFormProps) {
  const {
    query,
    setQuery,
    selectedExisting,
    toggleExisting,
    newInvites,
    queueNewInvite,
    removeNewInvite,
    updateNewInvite,
    submitting,
    submit,
    reset,
  } = useAddStudentsForm(batchId, onClose);

  const memberIdSet = new Set(currentMemberIds);
  const eligible = orgMembers.filter((m) => !memberIdSet.has(m.user_id));
  const filtered = query.trim()
    ? eligible.filter(
        (m) =>
          m.name.toLowerCase().includes(query.toLowerCase()) ||
          m.email.toLowerCase().includes(query.toLowerCase()),
      )
    : eligible;

  const noMatches = query.trim() !== "" && filtered.length === 0;
  const parsedNewInvite = noMatches ? parseNewInviteQuery(query) : null;

  const queuedExisting = orgMembers.filter((m) => selectedExisting.has(m.user_id));
  const totalQueued = queuedExisting.length + newInvites.length;
  const [editingIndex, setEditingIndex] = React.useState<number | null>(null);

  function handleClose() {
    reset();
    onClose();
  }

  return (
    <div className="flex w-full flex-col gap-4 min-w-0">
      <div className="relative">
        <Search aria-hidden className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground pointer-events-none" />
        <Input
          aria-label="Search org members by name or email, or type 'Name email@example.com' to invite someone new"
          className="pl-9"
          placeholder="Search, or type “Name email@example.com” to invite someone new…"
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && parsedNewInvite) {
              e.preventDefault();
              queueNewInvite(query);
            }
          }}
        />
      </div>

      {noMatches ? (
        <div className="rounded-md border border-dashed border-border p-3 flex items-center justify-between gap-3">
          <p className="text-sm text-muted-foreground">
            {parsedNewInvite ? (
              <>
                No org members match. Add <span className="font-medium text-foreground">{parsedNewInvite.fullName}</span>{" "}
                (<span className="font-medium text-foreground">{parsedNewInvite.email}</span>) as a new invite.
              </>
            ) : (
              <>No org members match &ldquo;{query}&rdquo;. Include an email to invite them instead.</>
            )}
          </p>
          <Button disabled={!parsedNewInvite} size="sm" onClick={() => queueNewInvite(query)}>
            <Plus aria-hidden className="mr-1.5 h-4 w-4" />
            Add
          </Button>
        </div>
      ) : filtered.length === 0 ? (
        <p className="text-sm text-muted-foreground">All org members are already in this batch.</p>
      ) : (
        <ul
          aria-label="Org members available to add"
          aria-multiselectable="true"
          className="max-h-56 overflow-y-auto divide-y divide-border rounded-md border border-border"
          role="listbox"
        >
          {filtered.map((m) => {
            const isSelected = selectedExisting.has(m.user_id);
            return (
              <li
                aria-selected={isSelected}
                className={`flex cursor-pointer items-center gap-3 px-3 py-2.5 text-sm transition-colors duration-fast hover:bg-muted ${
                  isSelected ? "bg-muted" : ""
                }`}
                key={m.user_id}
                role="option"
                tabIndex={0}
                onClick={() => toggleExisting(m.user_id)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" || e.key === " ") {
                    e.preventDefault();
                    toggleExisting(m.user_id);
                  }
                }}
              >
                <span
                  aria-hidden
                  className={`flex h-4 w-4 shrink-0 items-center justify-center rounded border ${
                    isSelected ? "border-primary bg-primary text-primary-foreground" : "border-border"
                  }`}
                >
                  {isSelected && (
                    <svg fill="none" height="10" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" viewBox="0 0 12 12" width="10">
                      <polyline points="2,6 5,9 10,3" />
                    </svg>
                  )}
                </span>
                <span className="flex flex-1 flex-col gap-0.5 min-w-0">
                  <span className="font-medium truncate">{m.name}</span>
                  <span className="text-xs text-muted-foreground truncate">{m.email}</span>
                </span>
                <span className="shrink-0 rounded bg-muted px-1.5 py-0.5 text-xs capitalize text-muted-foreground">
                  {m.role}
                </span>
              </li>
            );
          })}
        </ul>
      )}

      {totalQueued > 0 && (
        <div className="space-y-2">
          <p className="text-xs font-medium text-muted-foreground uppercase tracking-wide">
            To add ({totalQueued})
          </p>
          <div className="table-responsive rounded-md border border-border">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left text-xs text-muted-foreground">
                  <th className="px-3 py-2 font-medium">Name</th>
                  <th className="px-3 py-2 font-medium">Email</th>
                  <th className="px-3 py-2 font-medium">Type</th>
                  <th className="px-3 py-2 font-medium sr-only">Remove</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {queuedExisting.map((m) => (
                  <tr key={m.user_id}>
                    <td className="px-3 py-2 font-medium">{m.name}</td>
                    <td className="px-3 py-2 text-muted-foreground">{m.email}</td>
                    <td className="px-3 py-2">
                      <Badge variant="secondary">Existing member</Badge>
                    </td>
                    <td className="px-3 py-2 text-right">
                      <Button
                        aria-label={`Remove ${m.name} from the list to add`}
                        className="touch-target"
                        size="icon"
                        variant="ghost"
                        onClick={() => toggleExisting(m.user_id)}
                      >
                        <Trash2 aria-hidden className="h-4 w-4" />
                      </Button>
                    </td>
                  </tr>
                ))}
                {newInvites.map((invite, i) => (
                  <tr key={`${invite.email}-${i}`}>
                    <td className="px-3 py-2 font-medium">
                      {editingIndex === i ? (
                        <input
                          autoFocus
                          className="w-full px-2 py-1 border border-border rounded bg-background text-foreground"
                          type="text"
                          value={invite.full_name}
                          onChange={(e) => updateNewInvite(i, e.target.value)}
                          onBlur={() => setEditingIndex(null)}
                          onKeyDown={(e) => {
                            if (e.key === "Enter") setEditingIndex(null);
                            if (e.key === "Escape") setEditingIndex(null);
                          }}
                          aria-label={`Edit name for ${invite.email}`}
                        />
                      ) : (
                        <button
                          className="text-left hover:text-primary transition-colors"
                          type="button"
                          onClick={() => setEditingIndex(i)}
                          aria-label={`Edit name for ${invite.email}`}
                        >
                          {invite.full_name || "—"}
                        </button>
                      )}
                    </td>
                    <td className="px-3 py-2 text-muted-foreground">{invite.email}</td>
                    <td className="px-3 py-2">
                      <Badge>New invite</Badge>
                    </td>
                    <td className="px-3 py-2 text-right">
                      <Button
                        aria-label={`Remove queued invite for ${invite.full_name || invite.email}`}
                        className="touch-target"
                        size="icon"
                        variant="ghost"
                        onClick={() => removeNewInvite(i)}
                      >
                        <Trash2 aria-hidden className="h-4 w-4" />
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      <div className="flex items-center justify-between gap-3">
        <p className="text-sm text-muted-foreground">
          {totalQueued > 0 ? `${totalQueued} selected` : "Select or add students above"}
        </p>
        <div className="flex gap-2">
          <Button size="sm" variant="outline" onClick={handleClose}>
            Cancel
          </Button>
          <Button disabled={totalQueued === 0 || submitting} size="sm" onClick={submit}>
            <UserPlus aria-hidden className="mr-1.5 h-4 w-4" />
            {submitting ? "Adding…" : `Add ${totalQueued > 0 ? totalQueued : ""}`}
          </Button>
        </div>
      </div>
    </div>
  );
}

