"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { parseAsString, useQueryState } from "nuqs";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { ExternalLink, Pencil, RefreshCw, RotateCw, Trash2 } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { TeamMembersManager } from "@/components/projects/team-members-manager";
import { TeamActivityFeed } from "@/components/projects/team-activity-feed";
import { TeamDashboardSummary } from "@/components/projects/team-dashboard-summary";
import { TeamHandoffDialog } from "@/components/projects/team-handoff-dialog";
import { deleteTeamAction, reprovisionTeamAction, syncTeamAction, updateTeamAction } from "@/app/(app)/projects/actions";
import { PROVISION_STATUS_LABEL, PROVISION_VARIANT } from "@/lib/constants";
import type { ProjectTeam, ProjectTeamMember, TeamActivityView, TeamDashboardSummary as TeamDashboardSummaryType } from "@/lib/projects/types";
import type { BatchMember } from "@/lib/server/batches";

function useTeamActions(teamId: string, assignmentId: string) {
  const [pendingAction, setPendingAction] = React.useState<null | "reprovision" | "sync" | "delete">(null);
  const router = useRouter();

  async function run(action: "reprovision" | "sync" | "delete") {
    setPendingAction(action);
    const result =
      action === "reprovision"
        ? await reprovisionTeamAction(teamId, assignmentId)
        : action === "sync"
          ? await syncTeamAction(teamId, assignmentId)
          : await deleteTeamAction(teamId, assignmentId);
    setPendingAction(null);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(
      action === "reprovision" ? "Reprovisioning started." : action === "sync" ? "Roster sync started." : "Team deleted.",
    );
    router.refresh();
  }

  return { pendingAction, run };
}

const RenameSchema = z.object({
  name: z.string().min(2, "Name is too short."),
  slug: z.string().regex(/^[a-z0-9]+(-[a-z0-9]+)*$/, "Use lowercase letters, numbers, and hyphens only."),
});
type RenameFormData = z.infer<typeof RenameSchema>;

function RenameTeamDialog({ team, assignmentId }: { team: ProjectTeam; assignmentId: string }) {
  const [open, setOpen] = useQueryState("edit-team", parseAsString);
  const router = useRouter();
  const isOpen = open === team.id;
  const form = useForm<RenameFormData>({
    resolver: zodResolver(RenameSchema),
    defaultValues: { name: team.name, slug: team.slug },
  });

  const onSubmit = async (data: RenameFormData) => {
    const result = await updateTeamAction(team.id, assignmentId, data);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Team updated.");
    void setOpen(null);
    router.refresh();
  };

  return (
    <Dialog open={isOpen} onOpenChange={(next) => void setOpen(next ? team.id : null)}>
      <DialogTrigger asChild>
        <Button aria-label={`Rename ${team.name}`} size="icon" variant="ghost">
          <Pencil aria-hidden className="h-4 w-4" />
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Rename team</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField control={form.control} label="Team name" name="name" />
            <FormInputField control={form.control} label="Slug" name="slug" />
            <Button disabled={form.formState.isSubmitting} type="submit">
              {form.formState.isSubmitting ? "Saving…" : "Save"}
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}

interface TeamCardProps {
  team: ProjectTeam;
  assignmentId: string;
  members: ProjectTeamMember[];
  availableStudents: BatchMember[];
  activity: TeamActivityView;
  dashboard?: TeamDashboardSummaryType;
}

export function TeamCard({ team, assignmentId, members, availableStudents, activity, dashboard }: TeamCardProps) {
  const { pendingAction, run } = useTeamActions(team.id, assignmentId);
  const [confirmDeleteOpen, setConfirmDeleteOpen] = React.useState(false);

  return (
    <article className="card-base flex flex-col gap-3 p-6">
      <div className="flex items-start justify-between gap-2">
        <span className="text-base font-semibold">{team.name}</span>
        <Badge variant={PROVISION_VARIANT[team.provision_status] ?? "outline"}>
          {PROVISION_STATUS_LABEL[team.provision_status] ?? team.provision_status}
        </Badge>
      </div>

      {team.provision_status === "failed" && team.provision_error && (
        <p className="text-xs text-destructive">{team.provision_error}</p>
      )}

      {dashboard && <TeamDashboardSummary dashboard={dashboard} />}

      <div className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
        <span>{members.length} member{members.length === 1 ? "" : "s"}</span>
        {team.gitlab_web_url && (
          <a className="inline-flex items-center gap-1 hover:underline" href={team.gitlab_web_url} rel="noreferrer" target="_blank">
            Repo <ExternalLink aria-hidden className="h-3 w-3" />
          </a>
        )}
        {team.pages_url && (
          <a className="inline-flex items-center gap-1 hover:underline" href={team.pages_url} rel="noreferrer" target="_blank">
            Pages <ExternalLink aria-hidden className="h-3 w-3" />
          </a>
        )}
      </div>

      <div className="mt-auto flex flex-wrap items-center gap-2 pt-2">
        <TeamMembersManager assignmentId={assignmentId} availableStudents={availableStudents} members={members} team={team} />
        <TeamActivityFeed activity={activity} teamId={team.id} teamName={team.name} />
        <Button
          disabled={pendingAction !== null || team.provision_status !== "ready"}
          size="sm"
          title={team.provision_status !== "ready" ? "Sync is available once the team's GitLab project is provisioned." : undefined}
          variant="outline"
          onClick={() => void run("sync")}
        >
          <RefreshCw aria-hidden className="mr-1.5 h-3.5 w-3.5" />
          Sync
        </Button>
        <Button disabled={pendingAction !== null} size="sm" variant="outline" onClick={() => void run("reprovision")}>
          <RotateCw aria-hidden className="mr-1.5 h-3.5 w-3.5" />
          Reprovision
        </Button>
        <TeamHandoffDialog assignmentId={assignmentId} members={members} team={team} />
        <RenameTeamDialog assignmentId={assignmentId} team={team} />
        <Button
          aria-label={`Delete ${team.name}`}
          disabled={pendingAction !== null}
          size="icon"
          variant="ghost"
          onClick={() => setConfirmDeleteOpen(true)}
        >
          <Trash2 aria-hidden className="h-4 w-4 text-destructive" />
        </Button>
      </div>
      <ConfirmDialog
        destructive
        confirmLabel="Delete"
        description={`This permanently deletes "${team.name}" and its provisioned GitLab project. This can't be undone.`}
        open={confirmDeleteOpen}
        pending={pendingAction === "delete"}
        title={`Delete ${team.name}?`}
        onConfirm={() => void run("delete")}
        onOpenChange={setConfirmDeleteOpen}
      />
    </article>
  );
}
