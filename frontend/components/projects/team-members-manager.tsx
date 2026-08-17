"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { parseAsString, useQueryState } from "nuqs";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Trash2, UserPlus, Users } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormSelectField } from "@/components/ui/form-select-field";
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { UserLink } from "@/components/shared/user-link";
import { addTeamMemberAction, removeTeamMemberAction } from "@/app/(app)/projects/actions";
import { GITLAB_ACCESS_LEVEL_OPTIONS, PROJECT_TEAM_MEMBER_ROLE_OPTIONS } from "@/lib/constants";
import type { ProjectTeam, ProjectTeamMember } from "@/lib/projects/types";
import type { BatchMember } from "@/lib/server/batches";

const SYNC_VARIANT: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  pending:  "outline",
  synced:   "default",
  failed:   "destructive",
  removing: "secondary",
};

const AddMemberSchema = z.object({
  user_id: z.string().min(1, "Choose a student."),
  role: z.enum(["lead", "member"]),
  gitlab_access_level: z.string(),
});
type AddMemberFormData = z.infer<typeof AddMemberSchema>;

interface AddMemberFormProps {
  teamId: string;
  assignmentId: string;
  availableStudents: BatchMember[];
  onAdded: () => void;
}

function AddMemberForm({ teamId, assignmentId, availableStudents, onAdded }: AddMemberFormProps) {
  const form = useForm<AddMemberFormData>({
    resolver: zodResolver(AddMemberSchema),
    defaultValues: { user_id: "", role: "member", gitlab_access_level: "30" },
  });

  if (availableStudents.length === 0) {
    return <p className="text-sm text-muted-foreground">Every batch student already has a team on this assignment.</p>;
  }

  const onSubmit = async (data: AddMemberFormData) => {
    const result = await addTeamMemberAction(teamId, data.user_id, assignmentId, {
      role: data.role,
      gitlab_access_level: Number(data.gitlab_access_level) as 20 | 30 | 40,
    });
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Member added.");
    form.reset();
    onAdded();
  };

  const studentOptions = availableStudents.map((s) => ({ label: `${s.name} (${s.email})`, value: s.user_id }));

  return (
    <Form {...form}>
      <form className="flex flex-col gap-3 border-t border-border pt-4" onSubmit={form.handleSubmit(onSubmit)}>
        <FormSelectField control={form.control} label="Add student" name="user_id" options={studentOptions} placeholder="Choose a student" />
        <div className="grid grid-cols-2 gap-3">
          <FormSelectField control={form.control} label="Role" name="role" options={PROJECT_TEAM_MEMBER_ROLE_OPTIONS} />
          <FormSelectField control={form.control} label="Access level" name="gitlab_access_level" options={GITLAB_ACCESS_LEVEL_OPTIONS} />
        </div>
        <Button disabled={form.formState.isSubmitting} size="sm" type="submit">
          <UserPlus aria-hidden className="mr-1.5 h-4 w-4" />
          {form.formState.isSubmitting ? "Adding…" : "Add member"}
        </Button>
      </form>
    </Form>
  );
}

interface TeamMembersManagerProps {
  team: ProjectTeam;
  assignmentId: string;
  members: ProjectTeamMember[];
  availableStudents: BatchMember[];
}

export function TeamMembersManager({ team, assignmentId, members, availableStudents }: TeamMembersManagerProps) {
  const [openTeamId, setOpenTeamId] = useQueryState("team", parseAsString);
  const [removingIds, setRemovingIds] = React.useState<Set<string>>(new Set());
  const [confirmMember, setConfirmMember] = React.useState<{ userId: string; name: string } | null>(null);
  const router = useRouter();
  const isOpen = openTeamId === team.id;

  async function handleRemove(userId: string, name: string) {
    setRemovingIds((prev) => new Set(prev).add(userId));
    const result = await removeTeamMemberAction(team.id, userId, assignmentId);
    setRemovingIds((prev) => {
      const next = new Set(prev);
      next.delete(userId);
      return next;
    });
    setConfirmMember(null);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`${name} removed from team.`);
    router.refresh();
  }

  return (
    <Sheet open={isOpen} onOpenChange={(next) => void setOpenTeamId(next ? team.id : null)}>
      <SheetTrigger asChild>
        <Button size="sm" variant="outline">
          <Users aria-hidden className="mr-1.5 h-3.5 w-3.5" />
          Members ({members.length})
        </Button>
      </SheetTrigger>
      <SheetContent className="modal-responsive flex flex-col gap-4">
        <SheetHeader>
          <SheetTitle>{team.name} — members</SheetTitle>
        </SheetHeader>
        <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto">
          {members.length === 0 ? (
            <p className="text-sm text-muted-foreground">No members yet.</p>
          ) : (
            <ul className="divide-y divide-border rounded-md border border-border">
              {members.map((m) => (
                <li className="flex items-center gap-3 px-3 py-2.5 text-sm" key={m.user_id}>
                  <span className="flex flex-1 flex-col gap-0.5 min-w-0">
                    <UserLink className="truncate font-medium hover:underline" userId={m.user_id}>
                      {m.name || m.user_id}
                    </UserLink>
                    {m.email && <span className="truncate text-xs text-muted-foreground">{m.email}</span>}
                  </span>
                  <Badge variant={m.role === "lead" ? "default" : "secondary"}>{m.role}</Badge>
                  <Badge variant={SYNC_VARIANT[m.sync_status] ?? "outline"}>{m.sync_status}</Badge>
                  <Button
                    aria-label={`Remove ${m.name || "member"} from team`}
                    disabled={removingIds.has(m.user_id)}
                    size="icon"
                    variant="ghost"
                    onClick={() => setConfirmMember({ userId: m.user_id, name: m.name || "Member" })}
                  >
                    <Trash2 aria-hidden className="h-4 w-4 text-destructive" />
                  </Button>
                </li>
              ))}
            </ul>
          )}
          <AddMemberForm
            assignmentId={assignmentId}
            availableStudents={availableStudents}
            teamId={team.id}
            onAdded={() => router.refresh()}
          />
        </div>
      </SheetContent>
      <ConfirmDialog
        destructive
        confirmLabel="Remove"
        description={confirmMember ? `${confirmMember.name} will lose access to this team's repository and progress tracking.` : ""}
        open={confirmMember !== null}
        pending={confirmMember !== null && removingIds.has(confirmMember.userId)}
        title={confirmMember ? `Remove ${confirmMember.name} from team?` : "Remove member?"}
        onConfirm={() => confirmMember && handleRemove(confirmMember.userId, confirmMember.name)}
        onOpenChange={(open) => !open && setConfirmMember(null)}
      />
    </Sheet>
  );
}
