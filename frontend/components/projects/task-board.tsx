"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Plus, Trash2, User } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import {
  createTaskAction,
  deleteTaskAction,
  setTaskAssigneeAction,
  updateTaskStatusAction,
} from "@/app/(app)/projects/actions";
import { TASK_STATUS_LABEL, TASK_STATUS_OPTIONS, TASK_STATUS_VARIANT } from "@/lib/constants";
import type { ProjectTask, TaskStatus } from "@/lib/projects/types";

const Schema = z.object({
  title: z.string().min(2, "Title is too short."),
  description: z.string().optional(),
});
type FormData = z.infer<typeof Schema>;

function NewTaskDialog({ teamId }: { teamId: string }) {
  const [open, setOpen] = React.useState(false);
  const router = useRouter();
  const form = useForm<FormData>({ resolver: zodResolver(Schema), defaultValues: { title: "", description: "" } });

  const onSubmit = async (data: FormData) => {
    const result = await createTaskAction(teamId, { title: data.title, description: data.description?.trim() || null });
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Task added.");
    form.reset();
    setOpen(false);
    router.refresh();
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm">
          <Plus aria-hidden className="mr-1.5 h-4 w-4" />
          New task
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>New task</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField control={form.control} label="Title" name="title" placeholder="Wire up the login form" />
            <FormField
              control={form.control}
              name="description"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Description (optional)</FormLabel>
                  <FormControl>
                    <Textarea rows={3} {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <Button disabled={form.formState.isSubmitting} type="submit">
              {form.formState.isSubmitting ? "Adding…" : "Add task"}
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}

interface TaskCardProps {
  task: ProjectTask;
  teamId: string;
  currentUserId: string;
}

function TaskCard({ task, teamId, currentUserId }: TaskCardProps) {
  const router = useRouter();
  const [pending, setPending] = React.useState(false);
  const isMine = task.assignee_user_id === currentUserId;

  async function handleStatusChange(status: TaskStatus) {
    setPending(true);
    const result = await updateTaskStatusAction(task.id, teamId, status);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    router.refresh();
  }

  async function handleClaimToggle() {
    setPending(true);
    const result = await setTaskAssigneeAction(task.id, teamId, isMine ? null : currentUserId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    router.refresh();
  }

  async function handleDelete() {
    setPending(true);
    const result = await deleteTaskAction(task.id, teamId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    router.refresh();
  }

  return (
    <div className="card-base flex flex-col gap-2 p-4">
      <div className="flex items-start justify-between gap-2">
        <span className="text-sm font-medium">{task.title}</span>
        <Button aria-label="Delete task" disabled={pending} size="icon" variant="ghost" onClick={handleDelete}>
          <Trash2 aria-hidden className="h-3.5 w-3.5 text-destructive" />
        </Button>
      </div>
      {task.description && <p className="text-xs text-muted-foreground">{task.description}</p>}

      <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
        <User aria-hidden className="h-3 w-3" />
        {task.assignee_name || "Unassigned"}
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <Select disabled={pending} value={task.status} onValueChange={(v) => handleStatusChange(v as TaskStatus)}>
          <SelectTrigger className="h-8 w-full sm:w-[140px]">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {TASK_STATUS_OPTIONS.map((opt) => (
              <SelectItem key={opt.value} value={opt.value}>
                {opt.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Button disabled={pending} size="sm" variant="outline" onClick={handleClaimToggle}>
          {isMine ? "Unclaim" : "Claim"}
        </Button>
      </div>
    </div>
  );
}

interface TaskBoardProps {
  tasks: ProjectTask[];
  teamId: string;
  currentUserId: string;
}

// Lightweight, ungraded day-to-day board — status columns with a claim/
// unclaim self-assignment model rather than a full member-picker dropdown,
// since there's no student-facing team roster endpoint to populate one from
// (routes.go's GET .../members is staff-only) — see ProjectTask.AssigneeName's
// own doc comment (backend/internal/gitlab/models.go).
export function TaskBoard({ tasks, teamId, currentUserId }: TaskBoardProps) {
  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-4">
        <h2 className="section-title">Tasks</h2>
        <NewTaskDialog teamId={teamId} />
      </div>

      {tasks.length === 0 ? (
        <div className="empty-state py-10">
          <p className="text-sm text-muted-foreground">No tasks yet. Add one to start tracking day-to-day work.</p>
        </div>
      ) : (
        <div className="grid-responsive-4 grid gap-4">
          {TASK_STATUS_OPTIONS.map((col) => {
            const columnTasks = tasks.filter((t) => t.status === col.value);
            return (
              <div className="flex flex-col gap-2" key={col.value}>
                <Badge className="w-fit" variant={TASK_STATUS_VARIANT[col.value] ?? "outline"}>
                  {TASK_STATUS_LABEL[col.value] ?? col.label} ({columnTasks.length})
                </Badge>
                <div className="flex flex-col gap-2">
                  {columnTasks.map((task) => (
                    <TaskCard currentUserId={currentUserId} key={task.id} task={task} teamId={teamId} />
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
