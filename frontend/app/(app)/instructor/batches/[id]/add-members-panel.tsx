"use client";

import * as React from "react";
import { Plus, X, Search, UserPlus } from "lucide-react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { addBatchMembersAction } from "@/app/instructor/batches/actions";

export interface OrgMember {
  user_id: string;
  name: string;
  email: string;
  role: string;
}

// useAddMembersForm encapsulates the search + selection + submission state so
// the parent component stays within the 2-useState limit.
function useAddMembersForm(batchId: string, onDone: () => void) {
  const [query, setQuery] = React.useState("");
  const [selected, setSelected] = React.useState<Set<string>>(new Set());
  const [submitting, setSubmitting] = React.useState(false);
  const router = useRouter();

  function toggle(userId: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(userId)) {
        next.delete(userId);
      } else {
        next.add(userId);
      }
      return next;
    });
  }

  function reset() {
    setQuery("");
    setSelected(new Set());
  }

  async function submit() {
    if (selected.size === 0) return;
    setSubmitting(true);
    const result = await addBatchMembersAction(batchId, Array.from(selected));
    setSubmitting(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`${selected.size} member${selected.size === 1 ? "" : "s"} added.`);
    reset();
    onDone();
    router.refresh();
  }

  return { query, setQuery, selected, toggle, submitting, submit, reset };
}

interface AddMembersFormProps {
  batchId: string;
  orgMembers: OrgMember[];
  currentMemberIds: string[];
  onClose: () => void;
}

function AddMembersForm({ batchId, orgMembers, currentMemberIds, onClose }: AddMembersFormProps) {
  const { query, setQuery, selected, toggle, submitting, submit, reset } = useAddMembersForm(
    batchId,
    onClose,
  );

  const memberIdSet = new Set(currentMemberIds);
  const eligible = orgMembers.filter((m) => !memberIdSet.has(m.user_id));

  const filtered = query.trim()
    ? eligible.filter(
        (m) =>
          m.name.toLowerCase().includes(query.toLowerCase()) ||
          m.email.toLowerCase().includes(query.toLowerCase()),
      )
    : eligible;

  function handleClose() {
    reset();
    onClose();
  }

  return (
    <div className="card-raised flex w-full flex-col gap-4 p-6">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold">Add members</h2>
        <Button aria-label="Close add members panel" size="icon" variant="ghost" onClick={handleClose}>
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
        <p className="text-sm text-muted-foreground">All org members are already in this batch.</p>
      ) : filtered.length === 0 ? (
        <p className="text-sm text-muted-foreground">No members match your search.</p>
      ) : (
        <ul
          aria-label="Org members available to add"
          aria-multiselectable="true"
          className="max-h-64 overflow-y-auto divide-y divide-border rounded-md border border-border"
          role="listbox"
        >
          {filtered.map((m) => {
            const isSelected = selected.has(m.user_id);
            return (
              <li
                key={m.user_id}
                aria-selected={isSelected}
                className={`flex cursor-pointer items-center gap-3 px-3 py-2.5 text-sm transition-colors duration-fast hover:bg-muted ${
                  isSelected ? "bg-muted" : ""
                }`}
                role="option"
                onClick={() => toggle(m.user_id)}
              >
                <span
                  aria-hidden
                  className={`flex h-4 w-4 shrink-0 items-center justify-center rounded border ${
                    isSelected ? "border-primary bg-primary text-primary-foreground" : "border-border"
                  }`}
                >
                  {isSelected && (
                    <svg
                      fill="none"
                      height="10"
                      stroke="currentColor"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth="2.5"
                      viewBox="0 0 12 12"
                      width="10"
                    >
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

      <div className="flex items-center justify-between gap-3">
        <p className="text-sm text-muted-foreground">
          {selected.size > 0 ? `${selected.size} selected` : "Select members above"}
        </p>
        <div className="flex gap-2">
          <Button size="sm" variant="outline" onClick={handleClose}>
            Cancel
          </Button>
          <Button disabled={selected.size === 0 || submitting} size="sm" onClick={submit}>
            <Plus aria-hidden className="mr-1.5 h-4 w-4" />
            {submitting ? "Adding…" : `Add ${selected.size > 0 ? selected.size : ""}`}
          </Button>
        </div>
      </div>
    </div>
  );
}

interface AddMembersPanelProps {
  batchId: string;
  orgMembers: OrgMember[];
  currentMemberIds: string[];
}

export function AddMembersPanel({ batchId, orgMembers, currentMemberIds }: AddMembersPanelProps) {
  const [open, setOpen] = React.useState(false);

  if (!open) {
    return (
      <Button onClick={() => setOpen(true)} size="sm">
        <UserPlus aria-hidden className="mr-1.5 h-4 w-4" />
        Add members
      </Button>
    );
  }

  return (
    <AddMembersForm
      batchId={batchId}
      currentMemberIds={currentMemberIds}
      orgMembers={orgMembers}
      onClose={() => setOpen(false)}
    />
  );
}
