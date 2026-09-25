"use client";

import { useActionState, startTransition, useState } from "react";
import { ArrowLeft, Plus, Trash2, Loader2 } from "lucide-react";
import Link from "next/link";

import { saveStep4Action, type SaveStepState } from "@/app/org/setup/actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import ROUTES from "@/lib/routes";
import type { OrgRole } from "@/lib/orgs/types";

// ─── Role options ──────────────────────────────────────────────────────────────

const ROLE_OPTIONS: { value: OrgRole; label: string }[] = [
  { value: "admin", label: "Admin" },
  { value: "instructor", label: "Instructor" },
  { value: "mentor", label: "Mentor" },
  { value: "learner", label: "Learner" },
];

// ─── Types ────────────────────────────────────────────────────────────────────

interface InviteRow {
  id: number;
  email: string;
  role: OrgRole;
}

const INITIAL_STATE: SaveStepState = {};
let nextId = 1;

// ─── Component ────────────────────────────────────────────────────────────────

interface Step4TeamProps {
  orgId: string;
}

export function Step4Team({ orgId }: Step4TeamProps) {
  const [state, formAction, isPending] = useActionState(
    saveStep4Action,
    INITIAL_STATE,
  );

  const [rows, setRows] = useState<InviteRow[]>([
    { id: nextId++, email: "", role: "learner" },
  ]);

  function addRow() {
    setRows((prev) => [...prev, { id: nextId++, email: "", role: "learner" }]);
  }

  function removeRow(id: number) {
    setRows((prev) => prev.filter((r) => r.id !== id));
  }

  function updateEmail(id: number, email: string) {
    setRows((prev) =>
      prev.map((r) => (r.id === id ? { ...r, email } : r)),
    );
  }

  function updateRole(id: number, role: OrgRole) {
    setRows((prev) =>
      prev.map((r) => (r.id === id ? { ...r, role } : r)),
    );
  }

  const onSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const data = new FormData();
    data.set("org_id", orgId);
    rows.forEach((row, index) => {
      data.set(`invite_email_${index}`, row.email);
      data.set(`invite_role_${index}`, row.role);
    });
    startTransition(() => formAction(data));
  };

  return (
    <form noValidate className="form-stack" onSubmit={onSubmit}>
      <div className="mb-2">
        <h2 className="section-title">Invite Team</h2>
        <p className="text-sm text-muted-foreground">
          Invite members to join your organization. You can always invite more
          later.
        </p>
      </div>

      {state.error && (
        <p className="rounded-md border border-border bg-muted px-3 py-2.5 text-sm text-destructive" role="alert">
          {state.error}
        </p>
      )}

      {/* Invite rows */}
      <div className="flex flex-col gap-3">
        {rows.map((row, index) => (
          <div className="flex items-end gap-2" key={row.id}>
            <div className="flex flex-1 flex-col gap-1.5">
              {index === 0 && <Label htmlFor={`invite_email_${row.id}`}>Email</Label>}
              <Input
                autoComplete="off"
                disabled={isPending}
                id={`invite_email_${row.id}`}
                inputMode="email"
                placeholder="colleague@example.com"
                type="email"
                value={row.email}
                onChange={(e) => updateEmail(row.id, e.target.value)}
              />
            </div>

            <div className="flex w-36 flex-col gap-1.5">
              {index === 0 && <Label>Role</Label>}
              <Select
                disabled={isPending}
                value={row.role}
                onValueChange={(v) => updateRole(row.id, v as OrgRole)}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {ROLE_OPTIONS.map((opt) => (
                    <SelectItem key={opt.value} value={opt.value}>
                      {opt.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <button
              aria-label={`Remove invite row ${index + 1}`}
              className="touch-target mb-px flex items-center justify-center rounded-md text-muted-foreground transition-colors duration-fast hover:text-destructive disabled:pointer-events-none disabled:opacity-30"
              disabled={isPending || rows.length === 1}
              type="button"
              onClick={() => removeRow(row.id)}
            >
              <Trash2 aria-hidden className="h-4 w-4" />
            </button>
          </div>
        ))}
      </div>

      <Button
        className="gap-2 self-start"
        disabled={isPending}
        type="button"
        variant="outline"
        onClick={addRow}
      >
        <Plus aria-hidden className="h-4 w-4" />
        Add another
      </Button>

      <p className="text-xs text-muted-foreground">
        Invites expire after 7 days. Rows with empty emails are skipped.
      </p>

      <div className="flex-between pt-2">
        <Button
          asChild
          className="gap-2"
          disabled={isPending}
          type="button"
          variant="outline"
        >
          <Link href={`${ROUTES.ORG_SETUP}?step=3`}>
            <ArrowLeft aria-hidden className="h-4 w-4" />
            Back
          </Link>
        </Button>

        <Button className="gap-2" disabled={isPending} type="submit">
          {isPending ? (
            <>
              <Loader2 aria-hidden className="animate-spin" />
              Sending invites…
            </>
          ) : (
            "Send invites & finish"
          )}
        </Button>
      </div>
    </form>
  );
}
