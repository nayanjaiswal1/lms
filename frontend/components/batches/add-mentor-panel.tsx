"use client";

import * as React from "react";
import { Plus, X, Search, UserPlus } from "lucide-react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { addBatchMentorAction } from "@/lib/batches/actions";
import type { OrgMemberSummary } from "@/lib/server/batches";

interface AddMentorFormProps {
  batchId: string;
  orgMembers: OrgMemberSummary[];
  currentMentorIds: string[];
  onClose: () => void;
}

function AddMentorForm({ batchId, orgMembers, currentMentorIds, onClose }: AddMentorFormProps) {
  const [query, setQuery] = React.useState("");
  const [submitting, setSubmitting] = React.useState(false);
  const router = useRouter();

  const mentorIdSet = new Set(currentMentorIds);
  const eligible = orgMembers.filter((m) => !mentorIdSet.has(m.user_id));
  const filtered = query.trim()
    ? eligible.filter(
        (m) =>
          m.name.toLowerCase().includes(query.toLowerCase()) ||
          m.email.toLowerCase().includes(query.toLowerCase()),
      )
    : eligible;

  async function addMentor(userId: string, name: string) {
    setSubmitting(true);
    const result = await addBatchMentorAction(batchId, userId);
    setSubmitting(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`${name} added as mentor.`);
    onClose();
    router.refresh();
  }

  return (
    <div className="card-raised flex w-full flex-col gap-4 p-6">
      <div className="flex items-center justify-between">
        <h2 className="subsection-title">Add mentor</h2>
        <Button aria-label="Close add mentor panel" size="icon" variant="ghost" onClick={onClose}>
          <X aria-hidden className="h-4 w-4" />
        </Button>
      </div>

      <div className="relative">
        <Search aria-hidden className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground pointer-events-none" />
        <Input
          aria-label="Search org members by name or email"
          className="pl-9"
          placeholder="Search by name or email…"
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
      </div>

      {eligible.length === 0 ? (
        <p className="text-sm text-muted-foreground">All org members are already mentoring this batch.</p>
      ) : filtered.length === 0 ? (
        <p className="text-sm text-muted-foreground">No members match your search.</p>
      ) : (
        <ul
          aria-label="Org members available to add as mentor"
          className="max-h-64 overflow-y-auto divide-y divide-border rounded-md border border-border"
          role="listbox"
        >
          {filtered.map((m) => (
            <li
              aria-selected={false}
              className="flex items-center gap-3 px-3 py-2.5 text-sm"
              key={m.user_id}
              role="option"
            >
              <span className="flex flex-1 flex-col gap-0.5 min-w-0">
                <span className="font-medium truncate">{m.name}</span>
                <span className="text-xs text-muted-foreground truncate">{m.email}</span>
              </span>
              <span className="shrink-0 rounded bg-muted px-1.5 py-0.5 text-xs capitalize text-muted-foreground">
                {m.role}
              </span>
              <Button disabled={submitting} size="sm" variant="outline" onClick={() => addMentor(m.user_id, m.name)}>
                <Plus aria-hidden className="mr-1 h-3.5 w-3.5" />
                Add
              </Button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

interface AddMentorPanelProps {
  batchId: string;
  orgMembers: OrgMemberSummary[];
  currentMentorIds: string[];
}

export function AddMentorPanel({ batchId, orgMembers, currentMentorIds }: AddMentorPanelProps) {
  const [open, setOpen] = React.useState(false);

  if (!open) {
    return (
      <Button size="sm" onClick={() => setOpen(true)}>
        <UserPlus aria-hidden className="mr-1.5 h-4 w-4" />
        Add mentor
      </Button>
    );
  }

  return (
    <AddMentorForm
      batchId={batchId}
      currentMentorIds={currentMentorIds}
      orgMembers={orgMembers}
      onClose={() => setOpen(false)}
    />
  );
}
