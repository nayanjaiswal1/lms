"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { UserPlus, X } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Form } from "@/components/ui/form";
import { FormSelectField } from "@/components/ui/form-select-field";
import { useProjectRole } from "@/components/workspace/project-role-provider";
import { setAssigneesAction } from "@/lib/workspace/items-actions";
import { SuggestAssigneesButton } from "@/components/workspace/items/suggest-assignees-button";
import type { Assignee, AssigneeRole, ItemDetail } from "@/lib/workspace/types";

const ROLE_OPTIONS: { label: string; value: AssigneeRole }[] = [
  { label: "Owner", value: "owner" },
  { label: "Developer", value: "developer" },
  { label: "Reviewer", value: "reviewer" },
  { label: "Tester", value: "tester" },
];

const ROLE_GROUPS: AssigneeRole[] = ["owner", "developer", "reviewer", "tester"];
const ROLE_GROUP_LABEL: Record<AssigneeRole, string> = { owner: "Owner", developer: "Developers", reviewer: "Reviewers", tester: "Testers" };

const Schema = z.object({
  user_id: z.string().min(1, "Pick a member."),
  role: z.enum(["owner", "developer", "reviewer", "tester"]),
});
type FormData = z.infer<typeof Schema>;

interface AssigneePickerProps {
  workspaceId: string;
  item: ItemDetail;
  members: { user_id: string; name: string }[];
  currentUserId: string;
}

export function AssigneePicker({ workspaceId, item, members, currentUserId }: AssigneePickerProps) {
  const router = useRouter();
  const { atLeast, isLeadOf } = useProjectRole();
  // Manager+ or lead of the item's track may assign/remove anyone (contract-phase2.md "Assignees").
  const canManageAssignees = atLeast("manager") || (item.track_id !== null && isLeadOf(item.track_id));
  const [open, setOpen] = useState(false);
  const [pending, setPending] = useState(false);
  const form = useForm<FormData>({ resolver: zodResolver(Schema), defaultValues: { user_id: "", role: "developer" } });

  const hasOwner = item.assignees.some((a) => a.role === "owner");
  const canSelfAssignOwner = !canManageAssignees && !hasOwner;

  async function apply(next: Assignee[] | { user_id: string; role: AssigneeRole }[]) {
    setPending(true);
    const inputs = next.map((a) => ({ user_id: a.user_id, role: a.role }));
    const result = await setAssigneesAction(workspaceId, item.id, inputs);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Assignees updated.");
    router.refresh();
  }

  function remove(target: Assignee) {
    void apply(item.assignees.filter((a) => !(a.user_id === target.user_id && a.role === target.role)));
  }

  async function onAdd(data: FormData) {
    const deduped = item.assignees.filter((a) => !(a.user_id === data.user_id && a.role === data.role));
    await apply([...deduped, { user_id: data.user_id, role: data.role }]);
    setOpen(false);
    form.reset({ user_id: "", role: "developer" });
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <h2 className="text-sm font-medium text-muted-foreground">Assignees</h2>
        {canManageAssignees && (
        <div className="flex items-center gap-1">
          <SuggestAssigneesButton
            itemId={item.id}
            workspaceId={workspaceId}
            onAssign={(userId) => apply([...item.assignees, { user_id: userId, role: "developer" }])}
          />
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button aria-label="Add assignee" size="icon" variant="ghost">
                <UserPlus aria-hidden className="h-4 w-4" />
              </Button>
            </DialogTrigger>
            <DialogContent className="modal-responsive">
              <DialogHeader><DialogTitle>Add assignee</DialogTitle></DialogHeader>
              <Form {...form}>
                <form className="form-stack" onSubmit={form.handleSubmit(onAdd)}>
                  <FormSelectField
                    control={form.control}
                    label="Member"
                    name="user_id"
                    options={members.map((m) => ({ label: m.name, value: m.user_id }))}
                    placeholder="Select a member"
                  />
                  <FormSelectField control={form.control} label="Role" name="role" options={ROLE_OPTIONS} />
                  <DialogFooter>
                    <Button disabled={pending} type="submit">{pending ? "Adding…" : "Add"}</Button>
                  </DialogFooter>
                </form>
              </Form>
            </DialogContent>
          </Dialog>
        </div>
        )}
      </div>

      {canSelfAssignOwner && (
        <Button disabled={pending} size="sm" variant="outline" onClick={() => apply([...item.assignees, { user_id: currentUserId, role: "owner" }])}>
          Assign myself as owner
        </Button>
      )}

      {ROLE_GROUPS.map((role) => {
        const rows = item.assignees.filter((a) => a.role === role);
        if (rows.length === 0) return null;
        return (
          <div className="flex flex-col gap-1" key={role}>
            <p className="text-xs font-medium text-muted-foreground">{ROLE_GROUP_LABEL[role]}</p>
            {rows.map((a) => {
              const canRemove = canManageAssignees || a.user_id === currentUserId;
              return (
                <Badge className="w-fit gap-1.5 pr-1" key={`${a.user_id}-${a.role}`} variant="secondary">
                  {a.name}
                  {canRemove && (
                    <Button aria-label={`Remove ${a.name}`} className="rounded-full hover:bg-foreground/10" disabled={pending} type="button" variant="unstyled" onClick={() => remove(a)}>
                      <X className="h-3 w-3" />
                    </Button>
                  )}
                </Badge>
              );
            })}
          </div>
        );
      })}

      {item.assignees.length === 0 && !canSelfAssignOwner && <p className="text-sm text-muted-foreground">No one assigned yet.</p>}
    </div>
  );
}
